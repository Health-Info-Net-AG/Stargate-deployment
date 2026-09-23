#!/bin/sh
set -e

SECRETS_DIR="/secrets"
INIT_FILE="$SECRETS_DIR/.vault-initialized"
KEYS_FILE="$SECRETS_DIR/vault-keys.json"

echo "=== Vault Initialization Script ==="
echo "Waiting for Vault to be ready..."

READY_ATTEMPTS=0
READY_MAX_ATTEMPTS=150 # 150 * 2s = 5 minutes
until vault status -address=http://vault:8200 2>/dev/null | grep -q "Initialized"; do
  READY_ATTEMPTS=$((READY_ATTEMPTS + 1))
  if [ "$READY_ATTEMPTS" -ge "$READY_MAX_ATTEMPTS" ]; then
    echo "ERROR: Vault was not reachable after $((READY_MAX_ATTEMPTS * 2))s." >&2
    echo "  Check: docker compose logs vault" >&2
    exit 1
  fi
  sleep 2
done

# Keys go in on stdin (`key=-`), so no process argv carries one; `vault
# operator unseal` has no stdin form. sys/unseal needs no token.
unseal_from_keys_file() {
  for i in 0 1 2; do
    jq -r ".unseal_keys_b64[$i]" "$KEYS_FILE" \
      | vault write -address=http://vault:8200 sys/unseal key=- >/dev/null
  done
}

# Helper: validate vault-keys.json exists and is valid JSON
validate_keys_file() {
  if [ ! -f "$KEYS_FILE" ]; then
    echo "ERROR: Vault keys file not found at $KEYS_FILE"
    echo "Cannot unseal Vault automatically."
    return 1
  fi
  if ! jq empty "$KEYS_FILE" 2>/dev/null; then
    echo "ERROR: $KEYS_FILE is not valid JSON ($(wc -c < "$KEYS_FILE") bytes)."
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
      unseal_from_keys_file
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
  
  # Initialize Vault with 5 key shares and 3 key threshold
  ( umask 077; vault operator init $INIT_ARGS > "$KEYS_FILE" )
  
  chmod 600 "$KEYS_FILE"
  
  echo "Vault initialized. Keys stored in $KEYS_FILE"
  echo ""
  echo "=========================================="
  echo "IMPORTANT: Back up $KEYS_FILE securely!"
  echo "=========================================="
  echo ""
  
  ROOT_TOKEN=$(jq -r '.root_token' "$KEYS_FILE")

  echo "Unsealing Vault..."
  unseal_from_keys_file
  
  echo "Vault unsealed!"
  
  # Login with root token
  export VAULT_TOKEN="$ROOT_TOKEN"

  # Defer the WireGuard-key write until AFTER the KV mounts are enabled below
  # (secret-irisagent must exist first). This flag marks the first-time init so
  # the write happens once, on a fresh Vault only.
  FRESH_INIT=true

  # Keep the token out of this container's stdout; it stays in $KEYS_FILE.
  echo ""
  echo "=========================================="
  echo "Root token stored in $KEYS_FILE (mode 600)."
  echo "=========================================="
  echo ""
  
  # Also update the .env file token placeholder
  touch "$INIT_FILE"
fi

# Ensure KV-v2 mounts exist. Hoisted OUT of the first-init branch above so an UPGRADE of an
# already-initialized Vault (a box that predates a newly added service) still gets the new mounts --
# otherwise idagent/mailauth come up with no secret-idagent/secret-mailauth. All idempotent: `enable`
# on an existing path just logs "already exists".
# secret-policy has no reader or writer left, but stays: disabling a KV-v2 mount
# destroys the data under it, and existing boxes may hold some.
VAULT_MOUNTS="secret-smimekeys-client secret-policy secret-irisagent secret-mxengine secret-mtaconf secret-idagent secret-mailauth"

if [ -n "${VAULT_TOKEN:-}" ]; then
  echo "Ensuring Vault KV-v2 mounts..."
  for m in $VAULT_MOUNTS; do
    vault secrets enable -address=http://vault:8200 -path="$m" kv-v2 2>/dev/null || echo "  $m already exists"
  done
fi

# One token per service, scoped to the mounts it uses (comma-separated). Outside
# the first-init branch, like the mount loop above, so an existing Vault
# provisions on restart. The dashboard writes TLS keys to secret-mtaconf and
# DKIM/ARC keys to secret-mailauth.
SERVICE_SPECS="smimekeys-client:secret-smimekeys-client:rw
irisagent:secret-irisagent:rw
mxengine:secret-mxengine:rw
idagent:secret-idagent:rw
mtaconf:secret-mtaconf:rw
mailauth:secret-mailauth:ro
dashboard:secret-mtaconf,secret-mailauth:wo"

TOKENS_FILE="$SECRETS_DIR/service-tokens.env"

# Catches a server still on the 768h default.
MIN_TOKEN_TTL_SECONDS=31536000 # 1 year

# $1 = comma-separated mounts, $2 = kind. rw needs config: the Go clients POST
# it at startup.
policy_hcl() {
  for m in $(echo "$1" | tr ',' ' '); do
    case "$2" in
      rw)
        printf 'path "%s/config" { capabilities = ["create", "read", "update"] }\n' "$m"
        printf 'path "%s/data/*" { capabilities = ["create", "read", "update", "delete"] }\n' "$m"
        printf 'path "%s/metadata/*" { capabilities = ["read", "list", "delete"] }\n' "$m"
        ;;
      ro)
        printf 'path "%s/data/*" { capabilities = ["read"] }\n' "$m"
        printf 'path "%s/metadata/*" { capabilities = ["read", "list"] }\n' "$m"
        ;;
      wo)
        printf 'path "%s/data/*" { capabilities = ["create", "update"] }\n' "$m"
        ;;
      backup)
        printf 'path "%s/data/*" { capabilities = ["read"] }\n' "$m"
        printf 'path "%s/metadata/*" { capabilities = ["read", "list"] }\n' "$m"
        ;;
      restore)
        printf 'path "%s/data/*" { capabilities = ["create", "read", "update"] }\n' "$m"
        printf 'path "%s/metadata/*" { capabilities = ["read", "list"] }\n' "$m"
        ;;
    esac
  done
}

# $1 = file with one token per line.
revoke_tokens_in() {
  while read -r t; do
    [ -n "$t" ] || continue
    VAULT_TOKEN="$t" vault token revoke -address=http://vault:8200 -self >/dev/null 2>&1 || true
  done < "$1"
}

# `token lookup` with no argument is the self-lookup; there is no -self flag.
token_is_valid() {
  [ -n "$1" ] || return 1
  VAULT_TOKEN="$1" vault token lookup -address=http://vault:8200 >/dev/null 2>&1
}

token_ttl_ok() {
  ttl=$(VAULT_TOKEN="$1" vault token lookup -address=http://vault:8200 -format=json 2>/dev/null \
    | jq -r '.data.ttl // 0')
  [ -n "$ttl" ] && [ "$ttl" -ge "$MIN_TOKEN_TTL_SECONDS" ] 2>/dev/null
}

stored_token() {
  [ -f "$TOKENS_FILE" ] || return 1
  sed -n "s/^$1=\"\\(.*\\)\"\$/\\1/p" "$TOKENS_FILE" | head -1
}

if [ -n "${VAULT_TOKEN:-}" ]; then
  echo ""
  echo "Ensuring per-service Vault policies and tokens..."

  TOKENS_TMP="$SECRETS_DIR/.service-tokens.env.$$"
  # Revocation waits for the batch outcome: on success the replaced tokens go,
  # on failure the new ones do, so $TOKENS_FILE never names a revoked token.
  REPLACED_TMP="$SECRETS_DIR/.tokens-replaced.$$"
  MINTED_TMP="$SECRETS_DIR/.tokens-minted.$$"
  ( umask 077; : > "$TOKENS_TMP"; : > "$REPLACED_TMP"; : > "$MINTED_TMP" )
  PROVISION_FAILED=false

  ALL_MOUNTS=$(echo "$VAULT_MOUNTS" | tr ' ' ',')

  for spec in $SERVICE_SPECS "backup:$ALL_MOUNTS:backup" "restore:$ALL_MOUNTS:restore"; do
    svc=${spec%%:*}
    rest=${spec#*:}
    mount=${rest%%:*}
    kind=${rest##*:}
    policy="svc-$svc"
    var="VAULT_TOKEN_$(echo "$svc" | tr '[:lower:]' '[:upper:]' | tr '-' '_')"

    # Rewritten every run so a capability change lands without re-minting.
    policy_hcl "$mount" "$kind" \
      | vault policy write -address=http://vault:8200 "$policy" - >/dev/null || {
      echo "  ERROR: could not write policy $policy" >&2
      PROVISION_FAILED=true
      continue
    }

    # Re-mint when the stored token is invalid OR close enough to expiry that it
    # would lapse before the next release; this is what rotates them.
    token=$(stored_token "$var" || true)
    if token_is_valid "$token" && token_ttl_ok "$token"; then
      echo "  $svc: token present"
    else
      previous_token="$token"
      # Keep the built-in default policy (no -no-default-policy): it grants
      # sys/internal/ui/mounts/*, which every `vault kv` command reads to detect
      # KV-v2. Without it backup.sh and restore.sh fail on their first kv call.
      token=$(vault token create -address=http://vault:8200 \
        -policy="$policy" -orphan -ttl=87600h \
        -display-name="$svc" -field=token 2>/dev/null || true)
      if [ -z "$token" ]; then
        echo "  ERROR: could not mint a token for $svc" >&2
        PROVISION_FAILED=true
        continue
      fi
      if ! token_ttl_ok "$token"; then
        echo "  ERROR: the token minted for $svc expires in under a year." >&2
        echo "    max_lease_ttl in config/vault/vault.hcl has not taken effect." >&2
        echo "    Editing that file is not enough -- the container must be recreated:" >&2
        echo "      docker compose up -d --force-recreate vault" >&2
        VAULT_TOKEN="$token" vault token revoke -address=http://vault:8200 -self >/dev/null 2>&1 || true
        PROVISION_FAILED=true
        continue
      fi
      printf '%s\n' "$token" >> "$MINTED_TMP"
      if [ -n "$previous_token" ]; then
        printf '%s\n' "$previous_token" >> "$REPLACED_TMP"
      fi
      echo "  $svc: token minted"
    fi
    printf '%s="%s"\n' "$var" "$token" >> "$TOKENS_TMP"
  done

  if [ "$PROVISION_FAILED" = "true" ]; then
    revoke_tokens_in "$MINTED_TMP"
    rm -f "$TOKENS_TMP" "$REPLACED_TMP" "$MINTED_TMP"
    echo "ERROR: service token provisioning failed; leaving $TOKENS_FILE untouched." >&2
    exit 1
  fi

  # Revoke tokens for services that are no longer in SERVICE_SPECS; otherwise a
  # dropped service leaves a valid credential behind indefinitely.
  if [ -f "$TOKENS_FILE" ]; then
    for old_var in $(cut -d= -f1 "$TOKENS_FILE"); do
      grep -q "^$old_var=" "$TOKENS_TMP" && continue
      old=$(stored_token "$old_var" || true)
      if [ -n "$old" ]; then
        VAULT_TOKEN="$old" vault token revoke -address=http://vault:8200 -self \
          >/dev/null 2>&1 || true
        echo "  $old_var: revoked (service removed)"
      fi
    done
  fi

  mv "$TOKENS_TMP" "$TOKENS_FILE"
  chmod 600 "$TOKENS_FILE"
  echo "Service tokens written to $TOKENS_FILE (mode 600)."
  revoke_tokens_in "$REPLACED_TMP"
  rm -f "$REPLACED_TMP" "$MINTED_TMP"
fi

# Write the pre-configured WireGuard private key on first init ONLY, now that
# secret-irisagent exists (enabled just above). Doing this inside the first-init
# branch BEFORE the mounts were enabled failed with a 403 preflight error
# because the mount did not exist yet -- which broke restore.sh, where the
# restored customer-config always carries WG_PRIVATE_KEY so the write always ran.
if [ "${FRESH_INIT:-false}" = "true" ]; then
  if [ -n "$WG_PRIVATE_KEY" ]; then
    echo "Writing pre-configured WireGuard private key to Vault..."
    printf '%s' "$WG_PRIVATE_KEY" \
      | vault kv put -address=http://vault:8200 secret-irisagent/wg_private_key wg_private_key=- >/dev/null
    echo "WireGuard private key written to Vault!"
  else
    echo "No WG_PRIVATE_KEY provided - irisagent will generate a new key on first start."
  fi
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
