#!/bin/bash
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SECRETS_DIR="$PROJECT_DIR/secrets"
KEYS_FILE="$SECRETS_DIR/vault-keys.json"
ENV_FILE="$PROJECT_DIR/.env"
CONFIG_FILE="$PROJECT_DIR/customer-config.sh"

. "$SCRIPT_DIR/lib/env.sh"

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

# Extract and update token in .env
ROOT_TOKEN=$(jq -r '.root_token' "$KEYS_FILE")
if grep -q "^VAULT_TOKEN=" "$ENV_FILE" 2>/dev/null; then
  if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "s/^VAULT_TOKEN=.*/VAULT_TOKEN=\"$ROOT_TOKEN\"/" "$ENV_FILE"
  else
    sed -i "s/^VAULT_TOKEN=.*/VAULT_TOKEN=\"$ROOT_TOKEN\"/" "$ENV_FILE"
  fi
fi

# Start infrastructure first
echo "Starting infrastructure services..."
docker compose up -d postgres vault seaweedfs

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
  docker exec stargate-vault vault status > /dev/null 2>&1
  STATUS_EXIT=$?
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

  # Attempt unseal
  echo "  Unsealing Vault (attempt $ATTEMPT/$MAX_ATTEMPTS)..."
  docker exec stargate-vault vault operator unseal "$UNSEAL_KEY_1" > /dev/null 2>&1 || true
  docker exec stargate-vault vault operator unseal "$UNSEAL_KEY_2" > /dev/null 2>&1 || true
  docker exec stargate-vault vault operator unseal "$UNSEAL_KEY_3" > /dev/null 2>&1 || true

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

# Start application services
echo "Starting application services..."
docker compose up -d

# Start Dozzle if enabled
if [ -f "$CONFIG_FILE" ]; then
  DOZZLE_ENABLED_VALUE=$(read_env_var DOZZLE_ENABLED "$CONFIG_FILE")
  if [ "$DOZZLE_ENABLED_VALUE" = "true" ]; then
    echo "Starting Dozzle log viewer..."
    docker compose --profile dozzle up -d
  fi
fi

echo ""
echo "============================================"
echo "  Services Started"
echo "============================================"
echo ""

sleep 3
docker compose ps --format "table {{.Name}}\t{{.Status}}"

echo ""
echo "  Service URLs:"
echo "  -------------"
echo "  smimekeys-client:  http://localhost:8081"
echo "  policy:            http://localhost:8082"
echo "  irisagent:         http://localhost:8083"
echo "  mxengine:          http://localhost:8084"
echo ""
