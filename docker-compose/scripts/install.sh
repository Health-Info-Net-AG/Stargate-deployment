#!/bin/bash
set -eo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SECRETS_DIR="$PROJECT_DIR/secrets"
KEYS_FILE="$SECRETS_DIR/vault-keys.json"
ENV_FILE="$PROJECT_DIR/.env"
CONFIG_FILE="$PROJECT_DIR/customer-config.sh"

# Shared helpers (use SCRIPT_DIR/PROJECT_DIR defined above).
. "$SCRIPT_DIR/lib/systemd.sh"
. "$SCRIPT_DIR/lib/docker.sh"
. "$SCRIPT_DIR/lib/env.sh"

# install_docker() is provided by lib/docker.sh (sourced above).
# NOTE: the installer's prologue (distro detection, banner, already-installed
# check) lives in the "Main Installation" section below, AFTER the
# STARGATE_SOURCE_ONLY guard. This lets other scripts (e.g. update.sh) source
# this file purely for its functions without running the installer or exiting
# early when an installation already exists.

# check_dependencies() is provided by lib/docker.sh (sourced above).

# Function to update .env file with vault token
update_env_token() {
  local token="$1"
  if grep -q "^VAULT_TOKEN=" "$ENV_FILE"; then
      sed -i "s/^VAULT_TOKEN=.*/VAULT_TOKEN=\"$token\"/" "$ENV_FILE"
  else
    echo "VAULT_TOKEN=\"$token\"" >> "$ENV_FILE"
  fi
  echo "Updated VAULT_TOKEN in .env file"
}

# Generate a random password
generate_password() {
  local length=${1:-24}
  # openssl (already required by this script) gives finite CSPRNG output, so
  # unlike `tr < /dev/urandom | head` there is no early-closed pipe and no
  # "tr: write error: Broken pipe" under systemd/rc.local. Encode twice the
  # bytes we need, keep only alphanumerics, and trim to length.
  local random
  random=$(openssl rand -base64 "$((length * 2))" | LC_ALL=C tr -dc 'A-Za-z0-9')
  printf '%s' "${random:0:length}"
}

# Resolve an auto-generated secret WITHOUT rotating it on re-runs:
#   1. a value set in customer-config.sh wins;
#   2. else reuse the value already in .env -- so update.sh (or a re-install)
#      does NOT regenerate a password the running services and data volumes
#      still use, which would break Postgres/MinIO/Stalwart auth;
#   3. else generate a fresh one.
# Usage: VAR="$(resolve_secret "$VAR" ENV_KEY [length])"
resolve_secret() {
  local current="$1" key="$2" len="${3:-24}" existing
  if [ -n "$current" ]; then printf '%s' "$current"; return; fi
  existing="$(read_env_var "$key" "$ENV_FILE")"
  if [ -n "$existing" ]; then printf '%s' "$existing"; return; fi
  generate_password "$len"
}

# Persist a generated secret back to customer-config.sh so that update.sh
# (which re-sources customer-config.sh) preserves the same value. Only writes
# if the key is currently empty or missing in the file. Idempotent.
# Usage: persist_secret KEY VALUE FILE
persist_secret() {
  local key="$1" value="$2" file="$3"
  [ -n "$value" ] || return 0
  [ -f "$file" ] || return 0
  local current
  current="$(read_env_var "$key" "$file")"
  [ -z "$current" ] || return 0
  # Key exists but is empty -> update in place; key missing -> append
  if grep -q "^${key}=" "$file"; then
    sed -i "s|^${key}=.*|${key}=\"${value}\"|" "$file"
  else
    echo "${key}=\"${value}\"" >> "$file"
  fi
}

# ==============================================================================
# Customer Configuration Loading
# ==============================================================================

load_customer_config() {
  echo "============================================"
  echo "  Loading Customer Configuration"
  echo "============================================"
  echo ""

  # Bootstrap customer-config.sh if it doesn't exist yet, so a fresh install
  # works with zero manual setup. VM images bake their config at build time, so
  # this only fires for manual installs -- default to the prod template.
  # Generated values (vault token, IP, etc.) get written back here as
  # install progresses.
  if [ ! -f "$CONFIG_FILE" ]; then
    echo "customer-config.sh not found, bootstrapping from customer-config-prod.example.sh..."
    cp "$PROJECT_DIR/customer-config-prod.example.sh" "$CONFIG_FILE"
  fi

  # Source the config file
  source "$CONFIG_FILE"
  chmod 600 "$CONFIG_FILE"  # holds VAULT_TOKEN, WG private key, passwords

  # Sensible defaults for identification fields. Customer can override in
  # customer-config.sh; if left empty, derive from the system hostname so
  # the install completes without manual input on a fresh VM.
  CUSTOMER_NAME="${CUSTOMER_NAME:-$(hostname)}"
  DEPLOYMENT_NAME="${DEPLOYMENT_NAME:-${CUSTOMER_NAME}-stargate}"

  # Set defaults for optional fields
  POSTGRES_USER="${POSTGRES_USER:-postgres}"
  POSTGRES_PASSWORD="$(resolve_secret "$POSTGRES_PASSWORD" POSTGRES_PASSWORD)"
  # S3 credentials: support legacy MINIO_ROOT_USER/PASSWORD for existing customer-configs
  S3_ACCESS_KEY="${S3_ACCESS_KEY:-${MINIO_ROOT_USER:-minioadmin}}"
  S3_SECRET_KEY="$(resolve_secret "${S3_SECRET_KEY:-$MINIO_ROOT_PASSWORD}" S3_SECRET_KEY)"
  S3_BUCKET_NAME="${S3_BUCKET_NAME:-stargate-bucket}"

  SMIMEKEYS_VERSION="${SMIMEKEYS_VERSION:-dev}"
  POLICY_VERSION="${POLICY_VERSION:-dev}"
  IRISAGENT_VERSION="${IRISAGENT_VERSION:-dev}"
  MXENGINE_VERSION="${MXENGINE_VERSION:-dev}"
  DASHBOARD_VERSION="${DASHBOARD_VERSION:-dev}"
  CLAMAV_VERSION="${CLAMAV_VERSION:-1.4}"
  DOZZLE_VERSION="${DOZZLE_VERSION:-v10.5.0}"
  OPS_AGENT_VERSION="${OPS_AGENT_VERSION:-dev}"

  # Derive WG_LOCAL_IP and MXENGINE_PUBLIC_ADDRESS from SERVER_STATIC_IP
  SERVER_STATIC_IP="${SERVER_STATIC_IP:-}"
  if [ -z "$SERVER_STATIC_IP" ] && [ -n "$WG_LOCAL_IP" ] && [ "$WG_LOCAL_IP" != "10.0.0.1" ]; then
    # Backward compatibility: if SERVER_STATIC_IP not set but WG_LOCAL_IP is, use that
    SERVER_STATIC_IP="$WG_LOCAL_IP"
  fi

  # Auto-detect SERVER_STATIC_IP if still unset.
  # Uses the source IP of the default route (the VM's primary interface IP).
  # This can be a private IP if the VM is behind NAT - that's fine for
  # WG_LOCAL_IP, but the *_PUBLIC_URL values below also derive from it. If the
  # box is reached via a different public/floating IP, set SERVER_STATIC_IP (or
  # the individual *_PUBLIC_URL values) explicitly in customer-config.sh.
  #
  # The detected value is deliberately NOT written back to customer-config.sh.
  # Persisting it would freeze the first-detected IP: changing the VM's IP and
  # re-running purge+install would keep using the stale IP (and Keycloak login
  # would redirect to the old address). Leaving SERVER_STATIC_IP empty in the
  # config means every run re-detects and tracks the live interface IP. An
  # operator who wants a fixed value sets it explicitly, in which case the
  # branch above honors it and detection is skipped.
  if [ -z "$SERVER_STATIC_IP" ]; then
    SERVER_STATIC_IP=$(ip -4 route get 1.1.1.1 2>/dev/null \
      | awk '{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1); exit}}' || true)
    if [ -n "$SERVER_STATIC_IP" ]; then
      echo "Auto-detected SERVER_STATIC_IP=$SERVER_STATIC_IP (primary interface IP; override in customer-config.sh if reached via a different public IP)"
    fi
  fi

  if [ -z "$SERVER_STATIC_IP" ]; then
    echo "ERROR: SERVER_STATIC_IP is required and could not be auto-detected."
    echo "  Set it to this server's network IP address."
    echo "  Example: SERVER_STATIC_IP=\"10.0.1.50\""
    exit 1
  fi

  WG_LOCAL_IP="${WG_LOCAL_IP:-$SERVER_STATIC_IP}"
  MXENGINE_PUBLIC_ADDRESS="${MXENGINE_PUBLIC_ADDRESS:-http://${SERVER_STATIC_IP}:8084}"
  KEYCLOAK_PUBLIC_URL="${KEYCLOAK_PUBLIC_URL:-https://${SERVER_STATIC_IP}:8180}"
  DASHBOARD_PUBLIC_URL="${DASHBOARD_PUBLIC_URL:-https://${SERVER_STATIC_IP}}"
  DOZZLE_PUBLIC_URL="${DOZZLE_PUBLIC_URL:-https://${SERVER_STATIC_IP}:8190}"

  OUTBOUND_SEALER_MX_DOMAIN="${OUTBOUND_SEALER_MX_DOMAIN:-hintest.ch}"
  CERT_CA_IRISAGENT_DOMAIN="${CERT_CA_IRISAGENT_DOMAIN:-hintest.ch}"

  OUTBOUND_SMTP_HOST="${OUTBOUND_SMTP_HOST:-stalwart}"
  OUTBOUND_SMTP_PORT="${OUTBOUND_SMTP_PORT:-10026}"
  MTACONF_VERSION="${MTACONF_VERSION:-dev}"

  # Stalwart MTA. The mtaconf-svc user, its home domain, and the
  # initial hostname are all hardcoded synthetic values inside
  # provision.sh — they are deliberately not customer-config knobs.
  # The operator's real mail hostname is set later via mtaconf when
  # the dashboard form is submitted.
  STALWART_ADMIN_PASSWORD="$(resolve_secret "$STALWART_ADMIN_PASSWORD" STALWART_ADMIN_PASSWORD)"
  MTACONF_SVC_PASSWORD="$(resolve_secret "$MTACONF_SVC_PASSWORD" MTACONF_SVC_PASSWORD)"

  LOKI_URL="${LOKI_URL:-}"

  # Stargate deployment release tag — auto-detected from git on this repo
  APP_VERSION="$(detect_app_version "$PROJECT_DIR")"

  # Keycloak / APISIX / Dashboard
  KEYCLOAK_ADMIN_USER="${KEYCLOAK_ADMIN_USER:-admin}"
  KEYCLOAK_ADMIN_PASSWORD="$(resolve_secret "$KEYCLOAK_ADMIN_PASSWORD" KEYCLOAK_ADMIN_PASSWORD)"
  KEYCLOAK_APISIX_CLIENT_SECRET="$(resolve_secret "$KEYCLOAK_APISIX_CLIENT_SECRET" KEYCLOAK_APISIX_CLIENT_SECRET 32)"
  KEYCLOAK_DASHBOARD_CLIENT_SECRET="$(resolve_secret "$KEYCLOAK_DASHBOARD_CLIENT_SECRET" KEYCLOAK_DASHBOARD_CLIENT_SECRET 32)"
  KEYCLOAK_DOZZLE_CLIENT_SECRET="$(resolve_secret "$KEYCLOAK_DOZZLE_CLIENT_SECRET" KEYCLOAK_DOZZLE_CLIENT_SECRET 32)"
  # oauth2-proxy cookie secret must be exactly 16, 24, or 32 bytes -> 32 chars.
  OAUTH2_PROXY_COOKIE_SECRET="$(resolve_secret "$OAUTH2_PROXY_COOKIE_SECRET" OAUTH2_PROXY_COOKIE_SECRET 32)"
  APISIX_ADMIN_KEY="$(resolve_secret "$APISIX_ADMIN_KEY" APISIX_ADMIN_KEY 32)"
  DASHBOARD_SHOW_DEV_PAGES="${DASHBOARD_SHOW_DEV_PAGES:-false}"

  # WireGuard local configuration
  WG_INTERFACE_PORT="${WG_INTERFACE_PORT:-19818}"
  WG_TRANSPORT_MODE="${WG_TRANSPORT_MODE:-tcp}"
  WG_PRIVATE_KEY="${WG_PRIVATE_KEY:-}"  # Optional - if empty, irisagent will generate

  # Persist generated secrets back to customer-config.sh so that update.sh
  # preserves them across re-installs and updates. Only writes values that
  # are currently empty or missing in the file.
  persist_secret POSTGRES_PASSWORD "$POSTGRES_PASSWORD" "$CONFIG_FILE"
  persist_secret S3_SECRET_KEY "$S3_SECRET_KEY" "$CONFIG_FILE"
  persist_secret STALWART_ADMIN_PASSWORD "$STALWART_ADMIN_PASSWORD" "$CONFIG_FILE"
  persist_secret MTACONF_SVC_PASSWORD "$MTACONF_SVC_PASSWORD" "$CONFIG_FILE"
  persist_secret KEYCLOAK_ADMIN_PASSWORD "$KEYCLOAK_ADMIN_PASSWORD" "$CONFIG_FILE"
  persist_secret KEYCLOAK_APISIX_CLIENT_SECRET "$KEYCLOAK_APISIX_CLIENT_SECRET" "$CONFIG_FILE"
  persist_secret KEYCLOAK_DASHBOARD_CLIENT_SECRET "$KEYCLOAK_DASHBOARD_CLIENT_SECRET" "$CONFIG_FILE"
  persist_secret KEYCLOAK_DOZZLE_CLIENT_SECRET "$KEYCLOAK_DOZZLE_CLIENT_SECRET" "$CONFIG_FILE"
  persist_secret OAUTH2_PROXY_COOKIE_SECRET "$OAUTH2_PROXY_COOKIE_SECRET" "$CONFIG_FILE"
  persist_secret APISIX_ADMIN_KEY "$APISIX_ADMIN_KEY" "$CONFIG_FILE"

  echo "Customer: $CUSTOMER_NAME"
  echo "Deployment: $DEPLOYMENT_NAME"
  echo ""
}

# ==============================================================================
# Environment File Generation
# ==============================================================================

generate_env_file() {
  echo "============================================"
  echo "  Generating Environment File"
  echo "============================================"
  echo ""

  cat > "$ENV_FILE" << EOF
# ==============================================================================
# Stargate Environment Configuration
# ==============================================================================
# Generated from customer-config.sh on $(date)
# Customer: $CUSTOMER_NAME
# Deployment: $DEPLOYMENT_NAME
# ==============================================================================

# Deployment Identity
CUSTOMER_NAME="$CUSTOMER_NAME"
DEPLOYMENT_NAME="$DEPLOYMENT_NAME"

# PostgreSQL
POSTGRES_USER="$POSTGRES_USER"
POSTGRES_PASSWORD="$POSTGRES_PASSWORD"

# Vault (auto-populated after initialization)
VAULT_TOKEN=

# S3 (SeaweedFS)
S3_ACCESS_KEY="$S3_ACCESS_KEY"
S3_SECRET_KEY="$S3_SECRET_KEY"
S3_BUCKET_NAME="$S3_BUCKET_NAME"

# Application Versions
SMIMEKEYS_VERSION="$SMIMEKEYS_VERSION"
POLICY_VERSION="$POLICY_VERSION"
IRISAGENT_VERSION="$IRISAGENT_VERSION"
MXENGINE_VERSION="$MXENGINE_VERSION"
DASHBOARD_VERSION="$DASHBOARD_VERSION"
MTACONF_VERSION="$MTACONF_VERSION"
CLAMAV_VERSION="$CLAMAV_VERSION"
DOZZLE_VERSION="$DOZZLE_VERSION"
OPS_AGENT_VERSION="$OPS_AGENT_VERSION"

# Infrastructure Versions (image tags; \${VAR:-default} in compose falls back if empty)
POSTGRES_VERSION="$POSTGRES_VERSION"
KEYCLOAK_VERSION="$KEYCLOAK_VERSION"
VAULT_VERSION="$VAULT_VERSION"
APISIX_VERSION="$APISIX_VERSION"
NATS_VERSION="$NATS_VERSION"
SEAWEEDFS_VERSION="$SEAWEEDFS_VERSION"
CADDY_VERSION="$CADDY_VERSION"
LOKI_VERSION="$LOKI_VERSION"
ALLOY_VERSION="$ALLOY_VERSION"
NODE_EXPORTER_VERSION="$NODE_EXPORTER_VERSION"
STALWART_VERSION="$STALWART_VERSION"
OAUTH2_PROXY_VERSION="$OAUTH2_PROXY_VERSION"

# Stalwart MTA
STALWART_ADMIN_PASSWORD="$STALWART_ADMIN_PASSWORD"
MTACONF_SVC_PASSWORD="$MTACONF_SVC_PASSWORD"

# Mail Outbound Path
SERVER_STATIC_IP="$SERVER_STATIC_IP"
MXENGINE_PUBLIC_ADDRESS="$MXENGINE_PUBLIC_ADDRESS"
OUTBOUND_SEALER_MX_DOMAIN="$OUTBOUND_SEALER_MX_DOMAIN"
CERT_CA_IRISAGENT_DOMAIN="$CERT_CA_IRISAGENT_DOMAIN"
OUTBOUND_SMTP_HOST="$OUTBOUND_SMTP_HOST"
OUTBOUND_SMTP_PORT="$OUTBOUND_SMTP_PORT"

# Logging (Alloy -> Loki)
LOKI_URL="$LOKI_URL"
ALLOY_HOSTNAME="$DEPLOYMENT_NAME"

# Policy Sync (optional - syncs policies from Git repo)
# To enable: docker compose --profile policy-sync up -d
POLICY_SYNC_VERSION="${POLICY_SYNC_VERSION:-dev}"
POLICY_SYNC_REPO_URL="${POLICY_SYNC_REPO_URL:-https://github.com/Health-Info-Net-AG/Stargate-policies.git}"
POLICY_SYNC_REPO_USER="${POLICY_SYNC_REPO_USER:-}"
POLICY_SYNC_REPO_PASS="${POLICY_SYNC_REPO_PASS:-}"
POLICY_SYNC_REPO_BRANCH="${POLICY_SYNC_REPO_BRANCH:-}"
POLICY_SYNC_REPO_FOLDER="${POLICY_SYNC_REPO_FOLDER:-}"
POLICY_SYNC_INTERVAL="${POLICY_SYNC_INTERVAL:-1h}"

# Keycloak / APISIX / Dashboard
KEYCLOAK_ADMIN_USER="$KEYCLOAK_ADMIN_USER"
KEYCLOAK_ADMIN_PASSWORD="$KEYCLOAK_ADMIN_PASSWORD"
KEYCLOAK_APISIX_CLIENT_SECRET="$KEYCLOAK_APISIX_CLIENT_SECRET"
KEYCLOAK_DASHBOARD_CLIENT_SECRET="$KEYCLOAK_DASHBOARD_CLIENT_SECRET"
KEYCLOAK_DOZZLE_CLIENT_SECRET="$KEYCLOAK_DOZZLE_CLIENT_SECRET"
OAUTH2_PROXY_COOKIE_SECRET="$OAUTH2_PROXY_COOKIE_SECRET"
APISIX_ADMIN_KEY="$APISIX_ADMIN_KEY"
KEYCLOAK_PUBLIC_URL="$KEYCLOAK_PUBLIC_URL"
DASHBOARD_PUBLIC_URL="$DASHBOARD_PUBLIC_URL"
DOZZLE_PUBLIC_URL="$DOZZLE_PUBLIC_URL"
DASHBOARD_SHOW_DEV_PAGES="$DASHBOARD_SHOW_DEV_PAGES"
DASHBOARD_ROOT_URL="$DASHBOARD_ROOT_URL"
DASHBOARD_ROOT_DOMAIN="$DASHBOARD_ROOT_DOMAIN"

# Stargate deployment release tag (refreshed by start.sh on every boot)
APP_VERSION="$APP_VERSION"

# WireGuard Local Configuration
WG_LOCAL_IP="$WG_LOCAL_IP"
WG_INTERFACE_PORT="$WG_INTERFACE_PORT"
WG_TRANSPORT_MODE="$WG_TRANSPORT_MODE"

# WireGuard Private Key (optional - if set, written to Vault for irisagent)
WG_PRIVATE_KEY="${WG_PRIVATE_KEY:-}"

# Host install directory (auto-detected, used by ops-agent for git operations)
HOST_INSTALL_DIR="$(cd "$PROJECT_DIR/.." && pwd)"
EOF
  chmod 600 "$ENV_FILE"  # holds all generated secrets

  echo "Environment file created: $ENV_FILE"
  echo ""
}

# Generate a self-signed TLS certificate for the Caddy proxy.
# The cert is written to config/caddy/ssl/ and mounted read-only into the
# caddy container.  Skipped on re-runs when the cert already exists.
#
# A subjectAltName matching the server IP (or hostname) is required — modern
# browsers ignore the CN and reject certs that only have a CN with no SAN,
# showing NET::ERR_CERT_COMMON_NAME_INVALID instead of the bypassable
# NET::ERR_CERT_AUTHORITY_INVALID.
generate_tls_cert() {
  echo "============================================"
  echo "  Generating TLS Certificate"
  echo "============================================"
  echo ""

  local ssl_dir="$PROJECT_DIR/config/caddy/ssl"
  mkdir -p "$ssl_dir"

  if [ -f "$ssl_dir/server.crt" ] && [ -f "$ssl_dir/server.key" ]; then
    echo "TLS certificate already exists, skipping generation."
    echo ""
    return
  fi

  # Extract hostname/IP from KEYCLOAK_PUBLIC_URL (strip scheme and port)
  local kc_host
  kc_host=$(echo "$KEYCLOAK_PUBLIC_URL" | sed 's|https\?://||' | cut -d: -f1 | cut -d/ -f1)

  # Use IP: prefix for bare IP addresses, DNS: for hostnames.
  local san
  if [[ "$kc_host" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    san="IP:${kc_host},DNS:localhost"
  else
    san="DNS:${kc_host},DNS:localhost"
  fi

  openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
    -keyout "$ssl_dir/server.key" \
    -out    "$ssl_dir/server.crt" \
    -subj   "/CN=${kc_host}/O=Stargate" \
    -addext "subjectAltName=${san}" 2>/dev/null

  chmod 600 "$ssl_dir/server.key"
  echo "TLS certificate generated: $ssl_dir/server.crt"
  echo "  CN: $kc_host  |  SAN: $san  |  Valid: 10 years"
  echo ""
}

# Render config/keycloak/realm-stargate.json template into config/keycloak/generated/
# by substituting the two client-secret placeholders with the values from the
# customer config.  Keycloak does not resolve ${env.VAR} syntax at import time,
# so the substitution must happen before the container starts.
generate_keycloak_realm() {
  echo "============================================"
  echo "  Generating Keycloak Realm Config"
  echo "============================================"
  echo ""

  local out_dir="$PROJECT_DIR/config/keycloak/generated"
  mkdir -p "$out_dir"

  sed \
    -e "s|\${KEYCLOAK_APISIX_CLIENT_SECRET}|${KEYCLOAK_APISIX_CLIENT_SECRET}|g" \
    -e "s|\${KEYCLOAK_DASHBOARD_CLIENT_SECRET}|${KEYCLOAK_DASHBOARD_CLIENT_SECRET}|g" \
    -e "s|\${KEYCLOAK_DOZZLE_CLIENT_SECRET}|${KEYCLOAK_DOZZLE_CLIENT_SECRET}|g" \
    -e "s|\${DASHBOARD_PUBLIC_URL}|${DASHBOARD_PUBLIC_URL}|g" \
    -e "s|\${DOZZLE_PUBLIC_URL}|${DOZZLE_PUBLIC_URL}|g" \
    "$PROJECT_DIR/config/keycloak/realm-stargate.json" \
    > "$out_dir/realm-stargate.json"

  echo "Keycloak realm config generated: $out_dir/realm-stargate.json"
  echo ""
}

# setup_systemd_service() is provided by lib/systemd.sh (sourced above).

# Function to setup backup cron job
setup_backup_cron() {
  echo ""
  echo "Setting up daily backup cron job..."

  BACKUP_SCRIPT="$SCRIPT_DIR/backup.sh"

  # Create backups directory (target for the cron log).
  mkdir -p "$PROJECT_DIR/backups"

  # Use a system crontab drop-in (/etc/cron.d) instead of `crontab -l`/`crontab -`.
  # The per-user crontab tool resolves the target user -- and that user's home /
  # spool -- from the environment (LOGNAME/USER/HOME), which is not populated
  # the usual way when this runs from rc.local at boot, so it cannot deduce
  # root's crontab. A drop-in names the user explicitly in field 6 and needs no
  # environment; rewriting it on every run keeps it idempotent.
  local cron_file="/etc/cron.d/stargate-backup"
  cat > "$cron_file" << EOF
# Stargate daily backup -- managed by install.sh, do not edit by hand.
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
0 2 * * * root $BACKUP_SCRIPT >> $PROJECT_DIR/backups/cron.log 2>&1
EOF
  chmod 644 "$cron_file"
  # SELinux (Alma/RHEL, enforcing): apply the cron spool context so crond will
  # read the file. No-op / harmless on systems without SELinux.
  restorecon "$cron_file" 2>/dev/null || true

  echo "Daily backup scheduled at 2:00 AM ($cron_file)"
}

# Function to save Vault token to customer-config.sh for persistence
save_vault_token_to_config() {
  local token="$1"

  echo ""
  echo "============================================"
  echo "  Saving Vault Token to Config"
  echo "============================================"
  echo ""

  # Check if VAULT_TOKEN is empty or missing in customer-config.sh
  if grep -q '^VAULT_TOKEN=""' "$CONFIG_FILE" || grep -q '^VAULT_TOKEN=$' "$CONFIG_FILE" || ! grep -q '^VAULT_TOKEN=' "$CONFIG_FILE"; then
    # Update or add the token
    if grep -q '^VAULT_TOKEN=' "$CONFIG_FILE"; then
      sed -i "s|^VAULT_TOKEN=.*|VAULT_TOKEN=\"$token\"|" "$CONFIG_FILE"
    else
      # Add to file if not present
      echo "" >> "$CONFIG_FILE"
      echo "VAULT_TOKEN=\"$token\"" >> "$CONFIG_FILE"
    fi
    echo "Vault token saved to customer-config.sh"
    echo ""
    echo "  Token: ${token:0:15}...${token: -10}"
    echo ""
    echo "  IMPORTANT: Back up customer-config.sh before recreating the VM!"
    echo "  The same token will be used on restore."
  else
    echo "Vault token already configured in customer-config.sh"
  fi
}

# Function to extract WireGuard key from Vault and save to customer-config.sh
save_wireguard_key_to_config() {
  echo ""
  echo "============================================"
  echo "  Saving WireGuard Key to Config"
  echo "============================================"
  echo ""

  # Wait for irisagent to generate the key (it needs a moment after start)
  echo "Waiting for IRISAgent to initialize WireGuard key..."
  sleep 5

  # Extract the WireGuard private key from Vault
  WG_KEY=$(docker exec -e VAULT_TOKEN="$ROOT_TOKEN" stargate-vault \
    vault kv get -address=http://127.0.0.1:8200 -field=wg_private_key secret-irisagent/wg_private_key 2>/dev/null || echo "")

  if [ -z "$WG_KEY" ]; then
    echo "WARNING: Could not extract WireGuard key from Vault."
    echo "IRISAgent may not have started yet. You can extract it later with:"
    echo "  docker exec stargate-vault vault kv get -address=http://127.0.0.1:8200 secret-irisagent/wg_private_key"
    return 1
  fi

  # Get the public key from irisagent logs (display-only). `|| true`: grep exits
  # non-zero if the line isn't present yet, which would abort under pipefail.
  WG_PUBKEY=$(docker logs stargate-irisagent 2>&1 | grep "wireguard public key:" | head -1 | sed 's/.*wireguard public key: //' | tr -d '[:space:]' || true)

  # Check if WG_PRIVATE_KEY is already set in customer-config.sh
  if grep -q '^WG_PRIVATE_KEY=""' "$CONFIG_FILE" || grep -q "^WG_PRIVATE_KEY=\$" "$CONFIG_FILE" || ! grep -q '^WG_PRIVATE_KEY=' "$CONFIG_FILE"; then
    # Update or add the key
    if grep -q '^WG_PRIVATE_KEY=' "$CONFIG_FILE"; then
      sed -i "s|^WG_PRIVATE_KEY=.*|WG_PRIVATE_KEY=\"$WG_KEY\"|" "$CONFIG_FILE"
    else
      # No WG_PRIVATE_KEY line in the config (unusual) -- append it.
      echo "WG_PRIVATE_KEY=\"$WG_KEY\"" >> "$CONFIG_FILE"
    fi
    echo "WireGuard private key saved to customer-config.sh"
    echo ""
    echo "  Private Key: ${WG_KEY:0:10}...${WG_KEY: -10}"
    echo "  Public Key:  $WG_PUBKEY"
    echo ""
    echo "  IMPORTANT: Back up customer-config.sh before recreating the VM!"
    echo "  The same key will be used on next install."
  else
    echo "WireGuard key already configured in customer-config.sh"
  fi
}

# Function to setup Dozzle log viewer
setup_dozzle() {
  if [ "$DOZZLE_ENABLED" != "true" ]; then
    return 0
  fi

  echo ""
  echo "============================================"
  echo "  Setting up Dozzle Log Viewer"
  echo "============================================"
  echo ""

  # Authentication is handled by oauth2-proxy in front of Dozzle, against the
  # same Keycloak realm as the dashboard (client "dozzle"). The client/cookie
  # secrets and DOZZLE_PUBLIC_URL are resolved in load_customer_config and
  # written to .env, so there is nothing to generate here -- just start the
  # "dozzle" profile (dozzle + oauth2-proxy).
  echo "Starting Dozzle (behind oauth2-proxy -> Keycloak)..."
  docker compose --profile dozzle up -d
  echo "Dozzle started."
  echo ""
  echo "  Dozzle (logs): $DOZZLE_PUBLIC_URL"
  echo "  Log in with any user from the 'stargate' Keycloak realm (e.g. sg-admin)."
}

# ============================================
# Main Installation
# ============================================

# Allow other scripts to source this file for its functions without
# executing the installer. Usage: STARGATE_SOURCE_ONLY=1 source install.sh
if [ "${STARGATE_SOURCE_ONLY:-}" = "1" ]; then
  return 0 2>/dev/null || exit 0
fi

# Detect distribution / package manager (sets DIST_ID, PKGMGR) -- must run
# before check_dependencies, which may call install_docker.
detect_distro

cd "$PROJECT_DIR"

# Distinguish a manual console run from a non-interactive boot run (rc.local).
# rc.local has no controlling terminal, so stdin is not a tty there; an explicit
# STARGATE_BOOT=1 from rc.local makes the intent unambiguous even if stdin is
# redirected. INTERACTIVE=1 only for a human running this on the console.
if [ "${STARGATE_BOOT:-}" = "1" ] || [ ! -t 0 ]; then
  INTERACTIVE=0
else
  INTERACTIVE=1
fi

# Check if already installed.
if [ -f "$KEYS_FILE" ]; then
  # On boot (rc.local) an existing install is the normal steady state -- the
  # systemd unit brings the stack up -- so exit quietly with no output. Only a
  # human running this on the console gets the banner and the error guidance.
  if [ "$INTERACTIVE" = "1" ]; then
    echo "============================================"
    echo "  Stargate Installation"
    echo "============================================"
    echo ""
    echo "ERROR: Installation already completed."
    echo "Vault keys found at: $KEYS_FILE"
    echo ""
    echo "To start services, use: ./scripts/start.sh"
    echo "To reinstall, first run: ./scripts/purge.sh"
    exit 1
  fi
  exit 0
fi

# Fresh install -- show the banner for both manual and boot runs.
echo "============================================"
echo "  Stargate Installation"
echo "============================================"
echo ""

# Check dependencies first
check_dependencies


# Load and validate customer configuration
load_customer_config

# Create directories
mkdir -p "$SECRETS_DIR"
mkdir -p "$PROJECT_DIR/backups"

# Generate .env file from customer config
generate_env_file

# Generate self-signed TLS cert for the Caddy proxy
generate_tls_cert

# Generate Keycloak realm JSON with actual client secrets substituted in
generate_keycloak_realm

# Start infrastructure services first (Vault needs to initialize before
# application services can use the token).
echo ""
echo "Starting infrastructure services..."
docker compose up -d postgres vault vault-data-fixer seaweedfs seaweedfs-init

echo ""
echo "Waiting for Vault initialization..."
docker compose up -d vault-init

# Wait for vault-init to complete.
# `docker wait` blocks until the named container exits and prints its exit
# code on stdout. The previous implementation polled
# `docker compose ps vault-init | grep -q "running"`, but `docker compose ps`
# without `-a` hides exited containers and uses "Up ..." (not "running") for
# active ones, so the loop matched nothing and exited immediately — the
# script then raced past the freshly-written vault-keys.json and failed.
echo "Waiting for vault-init container to finish..."
docker compose logs -f vault-init 2>/dev/null &
LOG_PID=$!

VAULT_INIT_EXIT=$(docker wait stargate-vault-init 2>/dev/null) || VAULT_INIT_EXIT=1

kill $LOG_PID 2>/dev/null || true
wait $LOG_PID 2>/dev/null || true

if [ "$VAULT_INIT_EXIT" != "0" ]; then
  echo ""
  echo "ERROR: vault-init exited with code $VAULT_INIT_EXIT"
  echo "Check logs: docker compose logs vault-init"
  exit 1
fi

# Check if keys were generated
if [ -f "$KEYS_FILE" ]; then
  ROOT_TOKEN=$(jq -r '.root_token' "$KEYS_FILE")
  update_env_token "$ROOT_TOKEN"

  echo ""
  echo "============================================"
  echo "  Vault initialized successfully!"
  echo "============================================"
  echo ""
  echo "Root Token: $ROOT_TOKEN"
  echo ""
  echo "Keys saved to: $KEYS_FILE"
  echo "IMPORTANT: Back up this file securely!"
  echo ""

  # Save Vault token to customer-config.sh for persistence across VM recreations
  save_vault_token_to_config "$ROOT_TOKEN"

  # Now start all services - VAULT_TOKEN is set in .env so application
  # services will have the correct token from the start.
  echo "Starting all services..."
  docker compose up -d
  echo "All services started."

  # Wait for services to be ready
  sleep 5

  # Stalwart binds network listeners only at process start; stalwart-provision
  # creates the `reinject` listener (port 10026) via the management API, but
  # `ReloadSettings` does not rebind sockets. Wait for provisioning to finish,
  # then restart stalwart once so the newly-provisioned listeners actually come
  # up. Safe to re-run.
  echo "Waiting for Stalwart provisioning to complete..."
  docker wait stargate-stalwart-provision >/dev/null 2>&1 || true
  echo "Restarting Stalwart so provisioned listeners bind..."
  docker compose restart stalwart

  # Onboarding (domains, S/MIME CSR, irisagent peer config) is now performed
  # via the dashboard at /installation, /onboarding, and /mail.

  # Setup backup cron job
  setup_backup_cron

  # Create and enable systemd service for auto-start on boot
  setup_systemd_service

  # Save WireGuard key to customer-config.sh for persistence.
  # `|| true`: the key may not be in Vault yet (irisagent still starting); that's
  # a warning, not fatal -- don't let `set -e` abort the installer before the
  # completion banner / Dozzle setup.
  save_wireguard_key_to_config || true

  # Setup Dozzle if enabled
  setup_dozzle

else
  echo "ERROR: Vault keys file not found."
  echo "Check vault-init logs: docker compose logs vault-init"
  exit 1
fi

echo ""
echo "============================================"
echo "  Checking service status..."
echo "============================================"
echo ""

sleep 3
docker compose ps

echo ""
echo "============================================"
echo "  Installation Complete! ($APP_VERSION)"
echo "============================================"
echo ""
echo "  Customer: $CUSTOMER_NAME"
echo "  Deployment: $DEPLOYMENT_NAME"
echo ""
echo "  Dashboard:"
echo "  ----------"
echo "  URL:               $DASHBOARD_PUBLIC_URL"
echo ""
echo "  Keycloak Admin Console:"
echo "  -----------------------"
echo "  URL:               $KEYCLOAK_PUBLIC_URL/admin"
echo "  Username:          $KEYCLOAK_ADMIN_USER"
echo "  Password:          $KEYCLOAK_ADMIN_PASSWORD"
echo "  (You will be prompted to change the password on first login)"
echo ""
echo "  Service URLs:"
echo "  -------------"
echo "  smimekeys-client:  http://localhost:8081"
echo "  policy:            http://localhost:8082"
echo "  irisagent:         http://localhost:8083"
echo "  mxengine:          http://localhost:8084"
echo ""
echo "  PostgreSQL:        localhost:5432"
echo "  Stalwart SMTP:     localhost:25"
echo ""
echo "  Monitoring:"
echo "  -----------"
echo "  Node Exporter:     http://localhost:9100/metrics"
echo "  Alloy:             Logs -> $LOKI_URL"
if [ "${DOZZLE_ENABLED:-false}" = "true" ]; then
  echo "  Dozzle (logs):     $DOZZLE_PUBLIC_URL  (Keycloak login, realm 'stargate')"
fi
echo ""
echo "  Scripts:"
echo "  --------"
echo "  You can use systemctl or the scripts directly:"
echo "  systemctl {start|stop|status|restart} stargate"
echo "  ./scripts/start.sh  |  ./scripts/stop.sh"
echo "  Backup databases:  ./scripts/backup.sh"
echo "  Destroy all data:  ./scripts/purge.sh"
echo ""
echo "  Backups:"
echo "  --------"
echo "  Daily backups scheduled at 2:00 AM"
echo "  Backup location: $PROJECT_DIR/backups/"
echo ""
echo "  Configuration:"
echo "  --------------"
echo "  Customer config:   $CONFIG_FILE"
echo "  Environment file:  $ENV_FILE"
echo "  Vault keys:        $KEYS_FILE"
echo "  CSR file:          $SECRETS_DIR/signing-key.csr"
echo ""
echo "  IMPORTANT: Back up customer-config.sh before recreating the VM!"
echo "  It now contains your WireGuard private key for persistence."
echo ""
echo "  Browser TLS trust:"
echo "  ------------------"
echo "  Caddy uses a self-signed certificate for HTTPS."
echo "  Browsers will show a warning that can be bypassed via Advanced ->"
echo "  Accept the Risk (Firefox) or Proceed anyway (Chrome)."
echo "  To silence the warning permanently, import the certificate:"
echo ""
echo "    $PROJECT_DIR/config/caddy/ssl/server.crt"
echo ""
echo "  Import it into your OS/browser trust store (Keychain on macOS,"
echo "  Certificate Manager on Windows, update-ca-certificates on Debian/Ubuntu,"
echo "  update-ca-trust on RHEL/AlmaLinux). Firefox requires a separate import"
echo "  under Settings -> Privacy -> Certificates."
echo ""

echo ""
echo "============================================"
echo "  Next Steps"
echo "============================================"
echo ""
echo "  1. Open the dashboard at https://<SERVER_STATIC_IP>"
echo "  2. Complete the /installation page (WireGuard peer registration)"
echo "  3. Complete the /onboarding page (S/MIME certificate)"
echo "  4. Complete the /mail page (mail domains and relay config)"
echo ""
echo "  Recommended after onboarding:"
echo "    - SPF / DKIM / DMARC for your sending domains"
echo "    - Microsoft 365 / Exchange Online relay-back connectors"
echo ""
