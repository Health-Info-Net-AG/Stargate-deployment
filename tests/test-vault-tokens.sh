#!/bin/bash
# shellcheck disable=SC2034 # SCRIPT_DIR/PROJECT_DIR are lib/paths.sh's calling convention
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "$here/../docker-compose/scripts" && pwd)"
PROJECT_DIR=/opt/fake/docker-compose
SCRIPT_DIR="$PROJECT_DIR/scripts"
STARGATE_DATA_DIR=/tmp/sg-vault-tokens-test
rm -rf "$STARGATE_DATA_DIR"

. "$SCRIPTS_DIR/lib/paths.sh"
. "$SCRIPTS_DIR/lib/vault-tokens.sh"

mkdir -p "$SECRETS_DIR"

fail() { echo "FAIL: $*"; exit 1; }

# --- no tokens file -> refuses, leaves .env alone ----------------------------
printf 'FOO=bar\n' > "$ENV_FILE"
if sync_service_tokens_to_env 2>/dev/null; then
  fail "sync succeeded with no tokens file"
fi
grep -qx 'FOO=bar' "$ENV_FILE" || fail ".env was modified despite the failure"

# --- happy path --------------------------------------------------------------
cat > "$SERVICE_TOKENS_FILE" <<'EOF'
VAULT_TOKEN_MXENGINE="tok-mx"
VAULT_TOKEN_BACKUP="tok-bk"
EOF
sync_service_tokens_to_env >/dev/null || fail "sync failed on the happy path"
grep -qx 'FOO=bar' "$ENV_FILE" || fail "unrelated key lost"
grep -qx 'VAULT_TOKEN_MXENGINE="tok-mx"' "$ENV_FILE" || fail "mxengine token missing"
[ "$(stat -c %a "$ENV_FILE")" = 600 ] || fail ".env is not 600"

# --- a stale bare VAULT_TOKEN is dropped -------------------------------------
printf 'FOO=bar\nVAULT_TOKEN="root-leftover"\n' > "$ENV_FILE"
sync_service_tokens_to_env >/dev/null || fail "sync failed with a stale VAULT_TOKEN"
grep -q '^VAULT_TOKEN=' "$ENV_FILE" && fail "stale bare VAULT_TOKEN survived"
grep -qx 'FOO=bar' "$ENV_FILE" || fail "unrelated key lost"

# --- idempotent: no duplicated keys or headers on a second run ---------------
sync_service_tokens_to_env >/dev/null || fail "second sync failed"
[ "$(grep -c '^VAULT_TOKEN_MXENGINE=' "$ENV_FILE")" = 1 ] || fail "token key duplicated"
[ "$(grep -c '^# Per-service Vault tokens' "$ENV_FILE")" = 1 ] || fail "header duplicated"

# --- missing .env is created -------------------------------------------------
rm -f "$ENV_FILE"
sync_service_tokens_to_env >/dev/null || fail "sync failed with no .env"
grep -qx 'VAULT_TOKEN_BACKUP="tok-bk"' "$ENV_FILE" || fail "backup token missing"

# --- service_token ------------------------------------------------------------
[ "$(service_token VAULT_TOKEN_MXENGINE)" = "tok-mx" ] || fail "service_token returned the wrong value"
service_token VAULT_TOKEN_NOPE 2>/dev/null && fail "service_token succeeded for an unknown key"

# --- purge_root_token_from_config (restore.sh reaches it via this lib only) ---
printf 'FOO=bar\nVAULT_TOKEN="root-leftover"\n' > "$CONFIG_FILE"
purge_root_token_from_config >/dev/null || fail "purge failed"
grep -q '^VAULT_TOKEN=' "$CONFIG_FILE" && fail "legacy VAULT_TOKEN survived the purge"
grep -qx 'FOO=bar' "$CONFIG_FILE" || fail "purge dropped an unrelated key"
[ "$(stat -c %a "$CONFIG_FILE")" = 600 ] || fail "customer-config.sh is not 600 after purge"
purge_root_token_from_config >/dev/null || fail "purge failed with nothing to remove"
rm -f "$CONFIG_FILE"
purge_root_token_from_config >/dev/null || fail "purge failed with no config file"

rm -rf "$STARGATE_DATA_DIR"
echo "PASS"
