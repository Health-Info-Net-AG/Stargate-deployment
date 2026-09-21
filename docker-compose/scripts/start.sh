#!/bin/bash
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
. "$SCRIPT_DIR/lib/paths.sh"
KEYS_FILE="$SECRETS_DIR/vault-keys.json"

. "$SCRIPT_DIR/lib/env.sh"
. "$SCRIPT_DIR/lib/vault-tokens.sh"

cd "$PROJECT_DIR"

# Refresh APP_VERSION every start so a `git pull` to a newer tag is reflected
# in the dashboard without re-running install.sh. Exported so docker compose
# substitutes it ahead of any stale value in .env.
export APP_VERSION="$(detect_app_version "$PROJECT_DIR")"

echo "============================================"
echo "  Stargate - Starting Services ($APP_VERSION)"
echo "============================================"
echo ""

# Check if installation was completed
if [ ! -f "$KEYS_FILE" ]; then
  echo "ERROR: Installation not completed."
  echo "Please run: ./scripts/install.sh"
  exit 1
fi

# Check for required commands
if ! command -v docker &> /dev/null; then
  echo "ERROR: Docker is not installed."
  echo "Please run: ./scripts/install.sh"
  exit 1
fi

if ! command -v jq &> /dev/null; then
  echo "ERROR: jq is not installed."
  echo "Please install jq (e.g. 'sudo dnf install jq' or 'sudo apt install jq')."
  exit 1
fi

# Start infrastructure first
echo "Starting infrastructure services..."
compose up -d postgres vault seaweedfs

# Wait for Vault to be ready and unseal it
echo "Waiting for Vault to start..."
UNSEAL_KEY_1=$(jq -r '.unseal_keys_b64[0]' "$KEYS_FILE")
UNSEAL_KEY_2=$(jq -r '.unseal_keys_b64[1]' "$KEYS_FILE")
UNSEAL_KEY_3=$(jq -r '.unseal_keys_b64[2]' "$KEYS_FILE")

MAX_ATTEMPTS=30
ATTEMPT=0
VAULT_UNSEALED=false

while [ "$ATTEMPT" -lt "$MAX_ATTEMPTS" ]; do
  ATTEMPT=$((ATTEMPT + 1))

  # Check if Vault container is running and responsive
  # vault status exits 0=unsealed, 1=error, 2=sealed
  STATUS_EXIT=$(docker exec stargate-vault vault status > /dev/null 2>&1; echo $?)
  if [ "$STATUS_EXIT" -eq 1 ] || [ "$STATUS_EXIT" -eq 125 ] || [ "$STATUS_EXIT" -eq 126 ] || [ "$STATUS_EXIT" -eq 127 ]; then
    echo "  Vault not ready yet (attempt $ATTEMPT/$MAX_ATTEMPTS)..."
    sleep 2
    continue
  fi

  # Check if already unsealed
  if docker exec stargate-vault vault status 2>/dev/null | grep -q "Sealed.*false"; then
    VAULT_UNSEALED=true
    break
  fi

  echo "  Unsealing Vault (attempt $ATTEMPT/$MAX_ATTEMPTS)..."
  printf '%s' "$UNSEAL_KEY_1" | docker exec -i stargate-vault vault operator unseal - > /dev/null 2>&1 || true
  printf '%s' "$UNSEAL_KEY_2" | docker exec -i stargate-vault vault operator unseal - > /dev/null 2>&1 || true
  printf '%s' "$UNSEAL_KEY_3" | docker exec -i stargate-vault vault operator unseal - > /dev/null 2>&1 || true

  # Verify unseal succeeded
  if docker exec stargate-vault vault status 2>/dev/null | grep -q "Sealed.*false"; then
    VAULT_UNSEALED=true
    break
  fi

  sleep 2
done

if [ "$VAULT_UNSEALED" = true ]; then
  echo "Vault unsealed successfully!"
else
  echo "ERROR: Failed to unseal Vault after $MAX_ATTEMPTS attempts."
  echo "Check Vault logs: docker compose logs vault"
  exit 1
fi

# Must precede `compose up -d` -- see lib/vault-tokens.sh. A failure here is not
# fatal to the unit: the services that need no token still come up, which keeps
# the box diagnosable and stops a transient fault becoming a greenboot rollback.
echo ""
echo "Provisioning per-service Vault tokens..."
if ! ensure_service_tokens; then
  echo "WARNING: could not provision per-service Vault tokens." >&2
  echo "  Vault-backed services will fail to start until this is resolved." >&2
  echo "  Check: docker compose logs vault-init" >&2
fi

# Start application services
echo ""
echo "Starting application services..."
compose up -d

# Start Dozzle if enabled. --force-recreate because `docker compose down`
# leaves inactive-profile containers holding the removed network's id, and a
# plain `up` would start them -> "network <id> not found". Optional component,
# so a failure here must not fail the unit and turn the boot greenboot-RED.
if [ -f "$CONFIG_FILE" ]; then
  DOZZLE_ENABLED_VALUE=$(read_env_var DOZZLE_ENABLED "$CONFIG_FILE")
  if [ "$DOZZLE_ENABLED_VALUE" = "true" ]; then
    echo "Starting Dozzle log viewer..."
    if ! compose --profile dozzle up -d --force-recreate dozzle oauth2-proxy; then
      echo "WARNING: Dozzle failed to start; continuing without it." >&2
    fi
  fi
fi

echo ""
echo "============================================"
echo "  Services Started"
echo "============================================"
echo ""

sleep 3
compose ps --format "table {{.Name}}\t{{.Status}}"

echo ""
echo "  Service URLs:"
echo "  -------------"
echo "  smimekeys-client:  http://localhost:8081"
echo "  policy:            http://localhost:8082"
echo "  irisagent:         http://localhost:8083"
echo "  mxengine:          http://localhost:8084"
echo ""
