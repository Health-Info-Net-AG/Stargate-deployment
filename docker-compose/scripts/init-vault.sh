#!/bin/sh
set -e

SECRETS_DIR="/secrets"
INIT_FILE="$SECRETS_DIR/.vault-initialized"
KEYS_FILE="$SECRETS_DIR/vault-keys.json"

echo "=== Vault Initialization Script ==="
echo "Waiting for Vault to be ready..."

# Wait for Vault to be available
until vault status -address=http://vault:8200 2>/dev/null | grep -q "Initialized"; do
  sleep 2
done

# Helper: validate vault-keys.json exists and is valid JSON
validate_keys_file() {
  if [ ! -f "$KEYS_FILE" ]; then
    echo "ERROR: Vault keys file not found at $KEYS_FILE"
    echo "Cannot unseal Vault automatically."
    return 1
  fi
  if ! jq empty "$KEYS_FILE" 2>/dev/null; then
    echo "ERROR: $KEYS_FILE is not valid JSON."
    echo "File contents (first 5 lines):"
    head -5 "$KEYS_FILE"
    echo ""
    echo "The file may have been created by a manual 'vault operator init' without -format=json."
    echo "Please re-create it or fix it manually."
    return 1
  fi
  return 0
}

# Check if Vault is already initialized
INITIALIZED=$(vault status -address=http://vault:8200 -format=json 2>/dev/null | jq -r '.initialized')

if [ "$INITIALIZED" = "true" ]; then
  echo "Vault is already initialized."
  
  # Check if sealed
  SEALED=$(vault status -address=http://vault:8200 -format=json 2>/dev/null | jq -r '.sealed')
  
  if [ "$SEALED" = "true" ]; then
    echo "Vault is sealed. Attempting to unseal..."
    
    if validate_keys_file; then
      # Unseal with stored keys
      UNSEAL_KEY_1=$(jq -r '.unseal_keys_b64[0]' "$KEYS_FILE")
      UNSEAL_KEY_2=$(jq -r '.unseal_keys_b64[1]' "$KEYS_FILE")
      UNSEAL_KEY_3=$(jq -r '.unseal_keys_b64[2]' "$KEYS_FILE")
      
      vault operator unseal -address=http://vault:8200 "$UNSEAL_KEY_1"
      vault operator unseal -address=http://vault:8200 "$UNSEAL_KEY_2"
      vault operator unseal -address=http://vault:8200 "$UNSEAL_KEY_3"
      
      echo "Vault unsealed successfully!"
    else
      exit 1
    fi
  fi
  
  # Verify we can authenticate
  if [ -f "$KEYS_FILE" ] && jq empty "$KEYS_FILE" 2>/dev/null; then
    ROOT_TOKEN=$(jq -r '.root_token' "$KEYS_FILE")
    export VAULT_TOKEN="$ROOT_TOKEN"
  fi
  
else
  echo "Initializing Vault for the first time..."
  
  # Initialize Vault with 5 key shares and 3 key threshold
  # Note: Custom root tokens are no longer supported in Vault 1.19+
  # The root token will be auto-generated
  INIT_ARGS="-address=http://vault:8200 -key-shares=5 -key-threshold=3 -format=json"
  if [ -n "$VAULT_ROOT_TOKEN" ]; then
    echo "Note: VAULT_ROOT_TOKEN is set but custom root tokens are no longer supported in Vault 1.19+"
    echo "A new root token will be generated. Update your .env file after initialization."
  fi
  
  # Initialize Vault with 5 key shares and 3 key threshold
  vault operator init $INIT_ARGS > "$KEYS_FILE"
  
  chmod 600 "$KEYS_FILE"
  
  echo "Vault initialized. Keys stored in $KEYS_FILE"
  echo ""
  echo "=========================================="
  echo "IMPORTANT: Back up $KEYS_FILE securely!"
  echo "=========================================="
  echo ""
  
  # Extract keys and unseal
  UNSEAL_KEY_1=$(jq -r '.unseal_keys_b64[0]' "$KEYS_FILE")
  UNSEAL_KEY_2=$(jq -r '.unseal_keys_b64[1]' "$KEYS_FILE")
  UNSEAL_KEY_3=$(jq -r '.unseal_keys_b64[2]' "$KEYS_FILE")
  ROOT_TOKEN=$(jq -r '.root_token' "$KEYS_FILE")
  
  echo "Unsealing Vault..."
  vault operator unseal -address=http://vault:8200 "$UNSEAL_KEY_1"
  vault operator unseal -address=http://vault:8200 "$UNSEAL_KEY_2"
  vault operator unseal -address=http://vault:8200 "$UNSEAL_KEY_3"
  
  echo "Vault unsealed!"
  
  # Login with root token
  export VAULT_TOKEN="$ROOT_TOKEN"
  
  # Create KV-v2 mounts for each service
  echo "Creating Vault KV-v2 mounts..."
  
  vault secrets enable -address=http://vault:8200 -path=secret-smimekeys-client kv-v2 || echo "secret-smimekeys-client already exists"
  vault secrets enable -address=http://vault:8200 -path=secret-policy kv-v2 || echo "secret-policy already exists"
  vault secrets enable -address=http://vault:8200 -path=secret-irisagent kv-v2 || echo "secret-irisagent already exists"
  vault secrets enable -address=http://vault:8200 -path=secret-mxengine kv-v2 || echo "secret-mxengine already exists"
  vault secrets enable -address=http://vault:8200 -path=secret-mtaconf kv-v2 || echo "secret-mtaconf already exists"
  
  echo "Vault mounts created!"
  
  # Write WireGuard private key to Vault if provided
  if [ -n "$WG_PRIVATE_KEY" ]; then
    echo "Writing pre-configured WireGuard private key to Vault..."
    vault kv put -address=http://vault:8200 secret-irisagent/wg_private_key wg_private_key="$WG_PRIVATE_KEY"
    echo "WireGuard private key written to Vault!"
  else
    echo "No WG_PRIVATE_KEY provided - irisagent will generate a new key on first start."
  fi
  
  # Save root token to .env file hint
  echo ""
  echo "=========================================="
  echo "Add this to your .env file:"
  echo "VAULT_TOKEN=$ROOT_TOKEN"
  echo "=========================================="
  echo ""
  
  # Also update the .env file token placeholder
  touch "$INIT_FILE"
fi

# Output current Vault status
echo ""
echo "=== Vault Status ==="
vault status -address=http://vault:8200

echo ""
echo "=== Vault Mounts ==="
if [ -f "$KEYS_FILE" ] && jq empty "$KEYS_FILE" 2>/dev/null; then
  ROOT_TOKEN=$(jq -r '.root_token' "$KEYS_FILE")
  VAULT_TOKEN="$ROOT_TOKEN" vault secrets list -address=http://vault:8200 2>/dev/null || echo "Could not list mounts"
else
  echo "Could not list mounts (keys file missing or invalid)"
fi

echo ""
echo "Vault initialization complete!"
