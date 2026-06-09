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

echo "============================================"
echo "  Stargate - Starting Services"
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
docker compose up -d postgres vault minio

echo "Waiting for Vault to start..."
sleep 5

# Unseal Vault
echo "Unsealing Vault..."
UNSEAL_KEY_1=$(jq -r '.unseal_keys_b64[0]' "$KEYS_FILE")
UNSEAL_KEY_2=$(jq -r '.unseal_keys_b64[1]' "$KEYS_FILE")
UNSEAL_KEY_3=$(jq -r '.unseal_keys_b64[2]' "$KEYS_FILE")

docker exec stargate-vault vault operator unseal "$UNSEAL_KEY_1" > /dev/null 2>&1 || true
docker exec stargate-vault vault operator unseal "$UNSEAL_KEY_2" > /dev/null 2>&1 || true
docker exec stargate-vault vault operator unseal "$UNSEAL_KEY_3" > /dev/null 2>&1 || true

echo "Vault unsealed!"

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
