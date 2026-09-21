#!/bin/bash
# shellcheck disable=SC2034
# =============================================================================
# Shared library: per-service Vault tokens. Source lib/paths.sh first.
#
# init-vault.sh writes the tokens to $SERVICE_TOKENS_FILE; these helpers move
# them into .env. Compose substitutes ${VAULT_TOKEN_*} at parse time, so
# callers must run ensure_service_tokens() before `compose up -d`.
# =============================================================================

SERVICE_TOKENS_FILE="$SECRETS_DIR/service-tokens.env"

# Runs vault-init to completion; `docker wait` captures its exit code.
run_vault_init() {
  compose up -d vault-init || return 1

  local code
  code=$(docker wait stargate-vault-init 2>/dev/null) || code=1
  if [ "$code" != "0" ]; then
    echo "ERROR: vault-init exited with code $code" >&2
    echo "  Check logs: docker compose logs vault-init" >&2
    return 1
  fi
  return 0
}

# Rewritten wholesale so no value passes through a sed replacement.
sync_service_tokens_to_env() {
  if [ ! -f "$SERVICE_TOKENS_FILE" ]; then
    echo "ERROR: $SERVICE_TOKENS_FILE not found -- vault-init has not provisioned tokens." >&2
    return 1
  fi

  local tmp="${ENV_FILE}.tokens.$$"
  (
    umask 077
    if [ -f "$ENV_FILE" ]; then
      grep -v -e '^VAULT_TOKEN=' -e '^VAULT_TOKEN_' -e '^# Per-service Vault tokens' \
        "$ENV_FILE" > "$tmp" || true
    else
      : > "$tmp"
    fi
    echo "# Per-service Vault tokens - managed by init-vault.sh, do not edit by hand." >> "$tmp"
    cat "$SERVICE_TOKENS_FILE" >> "$tmp"
  ) || { rm -f "$tmp"; return 1; }

  mv "$tmp" "$ENV_FILE"
  chmod 600 "$ENV_FILE"
  echo "  ✓ Per-service Vault tokens synced to .env ($(grep -c '^VAULT_TOKEN_' "$ENV_FILE") services)"
  return 0
}

service_token() {
  [ -f "$SERVICE_TOKENS_FILE" ] || return 1
  local value
  value=$(sed -n "s/^$1=\"\\(.*\\)\"\$/\\1/p" "$SERVICE_TOKENS_FILE" | head -1)
  [ -n "$value" ] || return 1
  printf '%s' "$value"
}

ensure_service_tokens() {
  run_vault_init || return 1
  sync_service_tokens_to_env || return 1
  return 0
}
