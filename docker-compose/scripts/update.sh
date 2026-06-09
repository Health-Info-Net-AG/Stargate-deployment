#!/bin/bash
set -eo pipefail

# ==============================================================================
# Stargate Update Script
# ==============================================================================
# Re-reads customer-config.sh, regenerates .env, and restarts all services.
#
# Use cases:
#   - Bump image versions (change *_VERSION in customer-config.sh, then run this)
#   - Update mail domains, WireGuard config, or any other customer settings
#   - Change passwords or credentials (except VAULT_TOKEN, which is preserved)
#
# Usage:
#   ./scripts/update.sh              # regenerate .env and restart
#   ./scripts/update.sh --env-only   # regenerate .env without restarting
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$PROJECT_DIR/.env"

# Source install.sh for shared functions (load_customer_config, generate_env_file, etc.)
STARGATE_SOURCE_ONLY=1 source "$SCRIPT_DIR/install.sh"
. "$SCRIPT_DIR/lib/env.sh"

# Parse arguments
ENV_ONLY=false
for arg in "$@"; do
  case "$arg" in
    --env-only) ENV_ONLY=true ;;
    -h|--help)
      echo "Usage: $0 [--env-only]"
      echo ""
      echo "  --env-only   Regenerate .env without restarting services"
      echo ""
      echo "Edit customer-config.sh first, then run this script to apply changes."
      exit 0
      ;;
    *)
      echo "Unknown option: $arg"
      echo "Usage: $0 [--env-only]"
      exit 1
      ;;
  esac
done

cd "$PROJECT_DIR"

echo "============================================"
echo "  Stargate Configuration Update"
echo "============================================"
echo ""

# Preserve VAULT_TOKEN from current .env (tied to Vault unseal state)
EXISTING_VAULT_TOKEN=""
if [ -f "$ENV_FILE" ]; then
  EXISTING_VAULT_TOKEN=$(read_env_var VAULT_TOKEN "$ENV_FILE")
fi

# Fall back to vault-keys.json if .env has no token
KEYS_FILE="$PROJECT_DIR/secrets/vault-keys.json"
if [ -z "$EXISTING_VAULT_TOKEN" ] && [ -f "$KEYS_FILE" ]; then
  EXISTING_VAULT_TOKEN=$(jq -r '.root_token' "$KEYS_FILE" 2>/dev/null || true)
  if [ -n "$EXISTING_VAULT_TOKEN" ]; then
    echo "Recovered VAULT_TOKEN from vault-keys.json"
    echo ""
  fi
fi

if [ -z "$EXISTING_VAULT_TOKEN" ]; then
  echo "ERROR: No VAULT_TOKEN found in .env or vault-keys.json."
  echo "  Run init-vault.sh first, or re-run install.sh."
  exit 1
fi

# Load customer config (validates required fields, derives defaults)
load_customer_config

# Regenerate .env
generate_env_file

# Restore VAULT_TOKEN (generate_env_file writes it blank)
if [ -n "$EXISTING_VAULT_TOKEN" ]; then
  sed -i "s|^VAULT_TOKEN=.*|VAULT_TOKEN=\"$EXISTING_VAULT_TOKEN\"|" "$ENV_FILE"
  echo "Preserved VAULT_TOKEN from previous .env"
  echo ""
fi

if [ "$ENV_ONLY" = true ]; then
  echo "Done. .env updated (--env-only, services not restarted)."
  echo ""
  echo "To apply changes: docker compose down && docker compose up -d"
  exit 0
fi

# Restart services
echo "Stopping services..."
docker compose down

echo ""
echo "Starting services with updated configuration..."
docker compose up -d

# Handle Dozzle enable/disable and credential updates
update_dozzle() {
  local dozzle_enabled
  dozzle_enabled=$(read_env_var DOZZLE_ENABLED "$CONFIG_FILE")

  local dozzle_running
  dozzle_running=$(docker compose --profile dozzle ps --format '{{.Name}}' 2>/dev/null | grep -q stargate-dozzle && echo "true" || echo "false")

  if [ "$dozzle_enabled" != "true" ]; then
    if [ "$dozzle_running" = "true" ]; then
      echo ""
      echo "Dozzle disabled in config - stopping..."
      docker compose --profile dozzle down
    fi
    return 0
  fi

  # Dozzle is enabled - regenerate users.yml if credentials changed
  local dozzle_username dozzle_password
  dozzle_username=$(read_env_var DOZZLE_USERNAME "$CONFIG_FILE")
  dozzle_password=$(read_env_var DOZZLE_PASSWORD "$CONFIG_FILE")
  dozzle_username="${dozzle_username:-admin}"

  if [ -z "$dozzle_password" ]; then
    dozzle_password=$(generate_password 16)
    if grep -q '^DOZZLE_PASSWORD=' "$CONFIG_FILE"; then
      sed -i "s|^DOZZLE_PASSWORD=.*|DOZZLE_PASSWORD=\"$dozzle_password\"|" "$CONFIG_FILE"
    else
      echo "DOZZLE_PASSWORD=\"$dozzle_password\"" >> "$CONFIG_FILE"
    fi
  fi

  local dozzle_data_dir="$PROJECT_DIR/dozzle"
  mkdir -p "$dozzle_data_dir"

  local dozzle_image="amir20/dozzle:${DOZZLE_VERSION:-v10.5.0}"
  echo ""
  echo "Updating Dozzle credentials..."
  if docker run --rm "$dozzle_image" generate \
    "$dozzle_username" \
    --password "$dozzle_password" \
    --name "Stargate Admin" \
    --user-filter "name=stargate" \
    > "$dozzle_data_dir/users.yml" 2>/dev/null; then
    echo "  Dozzle credentials updated (user: $dozzle_username)"
  else
    echo "  WARNING: Failed to regenerate Dozzle users.yml"
  fi

  echo "Starting Dozzle..."
  docker compose --profile dozzle up -d
}

update_dozzle

echo ""
echo "============================================"
echo "  Update Complete"
echo "============================================"
echo ""
echo "  Changes applied from: $CONFIG_FILE"
echo "  Environment file:     $ENV_FILE"
echo ""
echo "  Verify with: docker compose ps"
echo ""
