#!/bin/bash
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
INVOCATION_DIR="$PWD"  # caller's working directory, captured before the cd below
SECRETS_DIR="$PROJECT_DIR/secrets"
ENV_FILE="$PROJECT_DIR/.env"
CONFIG_FILE="$PROJECT_DIR/customer-config.sh"

# Shared helpers (use SCRIPT_DIR/PROJECT_DIR defined above).
. "$SCRIPT_DIR/lib/systemd.sh"
. "$SCRIPT_DIR/lib/docker.sh"
. "$SCRIPT_DIR/lib/env.sh"

# Detect distribution / package manager (sets DIST_ID, PKGMGR).
detect_distro

cd "$PROJECT_DIR"

# ==============================================================================
# Usage
# ==============================================================================
usage() {
  echo "Usage: $0 <backup-file.tar.gz>"
  echo ""
  echo "Restore Stargate from a backup archive."
  echo ""
  echo "Arguments:"
  echo "  backup-file.tar.gz  Path to the backup archive (absolute or relative)"
  echo ""
  echo "Examples:"
  echo "  $0 backups/20260130_143022.tar.gz"
  echo "  $0 /root/stargate-backup.tar.gz"
  echo ""
  echo "This script will:"
  echo "  1. Stop any running services"
  echo "  2. Extract and validate the backup"
  echo "  3. Restore customer configuration"
  echo "  4. Install Docker if needed"
  echo "  5. Start infrastructure services (PostgreSQL, Vault, MinIO)"
  echo "  6. Restore the database"
  echo "  7. Restore Vault keys and unseal"
  echo "  8. Start application services (via the 'stargate' systemd unit)"
  echo ""
  exit 1
}

# Check arguments
if [ $# -ne 1 ]; then
  usage
fi

BACKUP_FILE="$1"

# Resolve the backup path. An absolute path is used as-is; otherwise try, in
# order: relative to the directory the command was run from, relative to the
# project root (the documented `backups/<file>` form), then the project's
# backups/ dir by bare filename.
if [[ "$BACKUP_FILE" = /* ]]; then
  :  # absolute, use as-is
elif [ -f "$INVOCATION_DIR/$BACKUP_FILE" ]; then
  BACKUP_FILE="$INVOCATION_DIR/$BACKUP_FILE"
elif [ -f "$PROJECT_DIR/$BACKUP_FILE" ]; then
  BACKUP_FILE="$PROJECT_DIR/$BACKUP_FILE"
elif [ -f "$PROJECT_DIR/backups/$(basename "$BACKUP_FILE")" ]; then
  BACKUP_FILE="$PROJECT_DIR/backups/$(basename "$BACKUP_FILE")"
fi

if [ ! -f "$BACKUP_FILE" ]; then
  echo "ERROR: Backup file not found: $1"
  echo "  Searched: $INVOCATION_DIR/, $PROJECT_DIR/, and $PROJECT_DIR/backups/"
  exit 1
fi

echo "============================================"
echo "  Stargate Restore"
echo "============================================"
echo ""
echo "Backup file: $BACKUP_FILE"
echo ""

# install_docker() and setup_systemd_service() are provided by lib/ (sourced above).

# check_dependencies() is provided by lib/docker.sh (sourced above).

# ==============================================================================
# 1. Stop Running Services
# ==============================================================================
echo "============================================"
echo "  1. Stopping Running Services"
echo "============================================"
echo ""

if docker compose ps -q 2>/dev/null | grep -q .; then
  echo "Stopping existing services..."
  docker compose down --remove-orphans 2>/dev/null || true
  echo "  ✓ Services stopped"
else
  echo "  - No running services found"
fi
echo ""

# ==============================================================================
# 2. Check Dependencies
# ==============================================================================
echo "============================================"
echo "  2. Checking Dependencies"
echo "============================================"
echo ""
check_dependencies
echo "  ✓ All dependencies satisfied"
echo ""

# ==============================================================================
# 3. Extract and Validate Backup
# ==============================================================================
echo "============================================"
echo "  3. Extracting Backup"
echo "============================================"
echo ""

RESTORE_DIR=$(mktemp -d)
echo "Extracting to: $RESTORE_DIR"

tar -xzf "$BACKUP_FILE" -C "$RESTORE_DIR"

# Find the backup subdirectory (timestamp folder). `|| true`: `head` closes the
# pipe early, which can SIGPIPE `find` and abort under `set -eo pipefail`; the
# empty-result case is handled by the check below.
BACKUP_CONTENT=$(find "$RESTORE_DIR" -mindepth 1 -maxdepth 1 -type d | head -1 || true)

if [ -z "$BACKUP_CONTENT" ]; then
  echo "ERROR: Invalid backup structure - no subdirectory found"
  rm -rf "$RESTORE_DIR"
  exit 1
fi

echo "  ✓ Backup extracted"

# Check manifest
if [ -f "$BACKUP_CONTENT/manifest.json" ]; then
  echo ""
  echo "Backup manifest:"
  # Display only -- don't let a malformed manifest abort restore under pipefail.
  jq . "$BACKUP_CONTENT/manifest.json" 2>/dev/null || cat "$BACKUP_CONTENT/manifest.json" || true
  echo ""

  BACKUP_VERSION=$(jq -r '.backup_version // "1.0"' "$BACKUP_CONTENT/manifest.json" 2>/dev/null || echo "1.0")
  if [ "$BACKUP_VERSION" != "2.0" ]; then
    echo "WARNING: Backup version $BACKUP_VERSION may not be fully compatible"
  fi
else
  echo "  - No manifest found (older backup format)"
fi

# Validate required files
MISSING_FILES=()
[ ! -f "$BACKUP_CONTENT/config/customer-config.sh" ] && MISSING_FILES+=("customer-config.sh")
[ ! -f "$BACKUP_CONTENT/database/full_dump.sql" ] && MISSING_FILES+=("full_dump.sql")

if [ ${#MISSING_FILES[@]} -gt 0 ]; then
  echo "ERROR: Missing required files in backup:"
  for f in "${MISSING_FILES[@]}"; do
    echo "  - $f"
  done
  rm -rf "$RESTORE_DIR"
  exit 1
fi

echo "  ✓ Backup validated"
echo ""

# ==============================================================================
# 4. Restore Customer Configuration
# ==============================================================================
echo "============================================"
echo "  4. Restoring Customer Configuration"
echo "============================================"
echo ""

# Backup existing config if present
if [ -f "$CONFIG_FILE" ]; then
  mv "$CONFIG_FILE" "${CONFIG_FILE}.bak.$(date +%s)"
  echo "  - Existing customer-config.sh backed up"
fi

cp "$BACKUP_CONTENT/config/customer-config.sh" "$CONFIG_FILE"
chmod 600 "$CONFIG_FILE"  # holds VAULT_TOKEN, WG private key, passwords
echo "  ✓ customer-config.sh restored"

# Source the restored config
source "$CONFIG_FILE"

echo ""
echo "  Customer: ${CUSTOMER_NAME:-unknown}"
echo "  Deployment: ${DEPLOYMENT_NAME:-unknown}"
echo ""

# ==============================================================================
# 5. Restore Secrets (Vault keys, CSR, certificates)
# ==============================================================================
echo "============================================"
echo "  5. Restoring Secrets"
echo "============================================"
echo ""

mkdir -p "$SECRETS_DIR"

# Restore vault keys
if [ -f "$BACKUP_CONTENT/secrets/vault-keys.json" ]; then
  cp "$BACKUP_CONTENT/secrets/vault-keys.json" "$SECRETS_DIR/"
  echo "  ✓ vault-keys.json restored"
  ROOT_TOKEN=$(jq -r '.root_token' "$SECRETS_DIR/vault-keys.json")
else
  echo "  ✗ WARNING: vault-keys.json not in backup"
  echo "    Vault will need to be reinitialized!"
  ROOT_TOKEN=""
fi

# Restore CSR
if [ -f "$BACKUP_CONTENT/secrets/signing-key.csr" ]; then
  cp "$BACKUP_CONTENT/secrets/signing-key.csr" "$SECRETS_DIR/"
  echo "  ✓ signing-key.csr restored"
fi

# Restore certificates
CERT_COUNT=0
for cert in "$BACKUP_CONTENT/secrets"/*.crt "$BACKUP_CONTENT/secrets"/*.pem "$BACKUP_CONTENT/secrets"/*.cer; do
  if [ -f "$cert" ]; then
    cp "$cert" "$SECRETS_DIR/"
    echo "  ✓ $(basename "$cert") restored"
    ((CERT_COUNT++)) || true
  fi
done

# Restore TLS certificates (Caddy)
if [ -d "$BACKUP_CONTENT/config/caddy-ssl" ] && [ "$(ls -A "$BACKUP_CONTENT/config/caddy-ssl" 2>/dev/null)" ]; then
  TLS_DIR="$PROJECT_DIR/config/caddy/ssl"
  mkdir -p "$TLS_DIR"
  cp "$BACKUP_CONTENT/config/caddy-ssl"/* "$TLS_DIR/"
  chmod 600 "$TLS_DIR"/*.key 2>/dev/null || true
  echo "  ✓ TLS certificates (Caddy) restored"
else
  echo "  - No TLS certificates in backup (will need to regenerate)"
fi

echo ""

# ==============================================================================
# 6. Generate Environment File
# ==============================================================================
echo "============================================"
echo "  6. Generating Environment File"
echo "============================================"
echo ""

# Set defaults for optional fields (same as install.sh)
POSTGRES_USER="${POSTGRES_USER:-postgres}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-postgres}"
MINIO_ROOT_USER="${MINIO_ROOT_USER:-minioadmin}"
MINIO_ROOT_PASSWORD="${MINIO_ROOT_PASSWORD:-minioadmin}"
S3_BUCKET_NAME="${S3_BUCKET_NAME:-stargate-bucket}"

SMIMEKEYS_VERSION="${SMIMEKEYS_VERSION:-dev}"
POLICY_VERSION="${POLICY_VERSION:-dev}"
IRISAGENT_VERSION="${IRISAGENT_VERSION:-dev}"
MXENGINE_VERSION="${MXENGINE_VERSION:-dev}"
MTACONF_VERSION="${MTACONF_VERSION:-dev}"
DASHBOARD_VERSION="${DASHBOARD_VERSION:-dev}"
DOZZLE_VERSION="${DOZZLE_VERSION:-v10.5.0}"

LOKI_URL="${LOKI_URL:-}"

# Keycloak / APISIX / Dashboard
KEYCLOAK_ADMIN_USER="${KEYCLOAK_ADMIN_USER:-admin}"
KEYCLOAK_ADMIN_PASSWORD="${KEYCLOAK_ADMIN_PASSWORD:-}"
KEYCLOAK_APISIX_CLIENT_SECRET="${KEYCLOAK_APISIX_CLIENT_SECRET:-}"
KEYCLOAK_DASHBOARD_CLIENT_SECRET="${KEYCLOAK_DASHBOARD_CLIENT_SECRET:-}"
APISIX_ADMIN_KEY="${APISIX_ADMIN_KEY:-}"
# IP-derived public URLs (and WG_LOCAL_IP below) live only in .env -- they are
# empty in customer-config.sh and derived at install time. Restore must
# re-derive them from SERVER_STATIC_IP, or Keycloak/dashboard/mxengine fall back
# to localhost. Mirror install.sh: use the configured IP, else auto-detect.
SERVER_STATIC_IP="${SERVER_STATIC_IP:-}"
if [ -z "$SERVER_STATIC_IP" ]; then
  SERVER_STATIC_IP=$(ip -4 route get 1.1.1.1 2>/dev/null \
    | awk '{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1); exit}}' || true)
fi
KEYCLOAK_PUBLIC_URL="${KEYCLOAK_PUBLIC_URL:-https://${SERVER_STATIC_IP}:8180}"
DASHBOARD_PUBLIC_URL="${DASHBOARD_PUBLIC_URL:-https://${SERVER_STATIC_IP}}"
MXENGINE_PUBLIC_ADDRESS="${MXENGINE_PUBLIC_ADDRESS:-http://${SERVER_STATIC_IP}:8084}"
DASHBOARD_SHOW_DEV_PAGES="${DASHBOARD_SHOW_DEV_PAGES:-false}"
DASHBOARD_ROOT_URL="${DASHBOARD_ROOT_URL:-}"
DASHBOARD_ROOT_DOMAIN="${DASHBOARD_ROOT_DOMAIN:-}"
DEPLOYMENT_NAME="${DEPLOYMENT_NAME:-stargate}"

# WireGuard local configuration
WG_LOCAL_IP="${WG_LOCAL_IP:-$SERVER_STATIC_IP}"
WG_INTERFACE_PORT="${WG_INTERFACE_PORT:-19818}"
WG_PRIVATE_KEY="${WG_PRIVATE_KEY:-}"

# Preserve the auto-generated credentials from the backed-up .env. They live
# only in .env (not customer-config.sh), so they must come from the backup to
# match the restored data volumes. Read them with read_env_var rather than
# `source`-ing the .env: a Compose .env may hold unquoted values (e.g. a
# CUSTOMER_NAME with a space) that `source` would execute as commands and
# abort the restore under `set -eo pipefail`.
BACKUP_ENV="$BACKUP_CONTENT/config/.env"
if [ -f "$BACKUP_ENV" ]; then
  for _k in POSTGRES_USER POSTGRES_PASSWORD MINIO_ROOT_USER MINIO_ROOT_PASSWORD \
            STALWART_ADMIN_PASSWORD MTACONF_SVC_PASSWORD KEYCLOAK_ADMIN_PASSWORD \
            KEYCLOAK_APISIX_CLIENT_SECRET KEYCLOAK_DASHBOARD_CLIENT_SECRET APISIX_ADMIN_KEY; do
    _v=$(read_env_var "$_k" "$BACKUP_ENV")
    if [ -n "$_v" ]; then printf -v "$_k" '%s' "$_v"; fi
  done
  echo "  ✓ Loaded credentials from backup .env"
fi

cat > "$ENV_FILE" << EOF
# ==============================================================================
# Stargate Environment Configuration
# ==============================================================================
# Restored from backup on $(date)
# Customer: $CUSTOMER_NAME
# Deployment: $DEPLOYMENT_NAME
# ==============================================================================

# PostgreSQL
POSTGRES_USER=$POSTGRES_USER
POSTGRES_PASSWORD=$POSTGRES_PASSWORD

# Vault
VAULT_TOKEN=${ROOT_TOKEN:-}

# MinIO (S3)
MINIO_ROOT_USER=$MINIO_ROOT_USER
MINIO_ROOT_PASSWORD=$MINIO_ROOT_PASSWORD
S3_BUCKET_NAME=$S3_BUCKET_NAME

# Application Versions
SMIMEKEYS_VERSION=$SMIMEKEYS_VERSION
POLICY_VERSION=$POLICY_VERSION
IRISAGENT_VERSION=$IRISAGENT_VERSION
MXENGINE_VERSION=$MXENGINE_VERSION
MTACONF_VERSION=$MTACONF_VERSION
DASHBOARD_VERSION=$DASHBOARD_VERSION
DOZZLE_VERSION=$DOZZLE_VERSION
CLAMAV_VERSION=${CLAMAV_VERSION:-1.4}

# Deployment
CUSTOMER_NAME=$CUSTOMER_NAME
DEPLOYMENT_NAME=$DEPLOYMENT_NAME

# Stalwart MTA
STALWART_ADMIN_PASSWORD=$STALWART_ADMIN_PASSWORD
MTACONF_SVC_PASSWORD=$MTACONF_SVC_PASSWORD

# Mail Outbound Path
SERVER_STATIC_IP=$SERVER_STATIC_IP
MXENGINE_PUBLIC_ADDRESS=$MXENGINE_PUBLIC_ADDRESS
OUTBOUND_SEALER_MX_DOMAIN=$OUTBOUND_SEALER_MX_DOMAIN
CERT_CA_IRISAGENT_DOMAIN=$CERT_CA_IRISAGENT_DOMAIN
OUTBOUND_SMTP_HOST=$OUTBOUND_SMTP_HOST
OUTBOUND_SMTP_PORT=$OUTBOUND_SMTP_PORT

# Logging
LOKI_URL=$LOKI_URL
ALLOY_HOSTNAME=$DEPLOYMENT_NAME

# Keycloak / APISIX / Dashboard
KEYCLOAK_ADMIN_USER=$KEYCLOAK_ADMIN_USER
KEYCLOAK_ADMIN_PASSWORD=$KEYCLOAK_ADMIN_PASSWORD
KEYCLOAK_APISIX_CLIENT_SECRET=$KEYCLOAK_APISIX_CLIENT_SECRET
KEYCLOAK_DASHBOARD_CLIENT_SECRET=$KEYCLOAK_DASHBOARD_CLIENT_SECRET
APISIX_ADMIN_KEY=$APISIX_ADMIN_KEY
KEYCLOAK_PUBLIC_URL=$KEYCLOAK_PUBLIC_URL
DASHBOARD_PUBLIC_URL=$DASHBOARD_PUBLIC_URL
DASHBOARD_SHOW_DEV_PAGES=$DASHBOARD_SHOW_DEV_PAGES
DASHBOARD_ROOT_URL=$DASHBOARD_ROOT_URL
DASHBOARD_ROOT_DOMAIN=$DASHBOARD_ROOT_DOMAIN

# Policy Sync
POLICY_SYNC_VERSION=${POLICY_SYNC_VERSION:-dev}
POLICY_SYNC_REPO_URL=${POLICY_SYNC_REPO_URL:-}
POLICY_SYNC_REPO_USER=${POLICY_SYNC_REPO_USER:-}
POLICY_SYNC_REPO_PASS=${POLICY_SYNC_REPO_PASS:-}
POLICY_SYNC_REPO_BRANCH=${POLICY_SYNC_REPO_BRANCH:-}
POLICY_SYNC_REPO_FOLDER=${POLICY_SYNC_REPO_FOLDER:-}
POLICY_SYNC_INTERVAL=${POLICY_SYNC_INTERVAL:-1h}

# WireGuard Local Configuration
WG_LOCAL_IP=$WG_LOCAL_IP
WG_INTERFACE_PORT=$WG_INTERFACE_PORT
WG_TRANSPORT_MODE=${WG_TRANSPORT_MODE:-tcp}
WG_PRIVATE_KEY=${WG_PRIVATE_KEY:-}
EOF
chmod 600 "$ENV_FILE"  # holds all secrets

echo "  ✓ Environment file generated"
echo ""

# ==============================================================================
# 7. Start Infrastructure Services
# ==============================================================================
echo "============================================"
echo "  7. Starting Infrastructure Services"
echo "============================================"
echo ""

echo "Starting PostgreSQL, Vault, MinIO..."
docker compose up -d postgres vault minio

echo "Waiting for PostgreSQL to be ready..."
# Probe over TCP (-h 127.0.0.1), NOT the Unix socket. On a fresh data volume the
# postgres image first runs a temporary socket-only server to execute the init
# scripts, then shuts it down and starts the real server on TCP. A socket
# pg_isready answers "ready" during that init phase, so the restore would race
# the init -> real-server restart. Waiting for TCP avoids that race.
pg_ready=false
for i in {1..60}; do
  if docker exec stargate-postgres pg_isready -h 127.0.0.1 -U "$POSTGRES_USER" > /dev/null 2>&1; then
    echo "  ✓ PostgreSQL is ready"
    pg_ready=true
    break
  fi
  echo "  Waiting... ($i/60)"
  sleep 2
done

if [ "$pg_ready" != true ]; then
  echo "ERROR: PostgreSQL did not become ready (TCP) in time"
  exit 1
fi
echo ""

# ==============================================================================
# 8. Restore Database
# ==============================================================================
echo "============================================"
echo "  8. Restoring Database"
echo "============================================"
echo ""

echo "Restoring full database dump..."
# Capture psql's real exit status (a dropped connection -> non-zero) rather than
# masking it behind the noise filter, so a mid-restore failure (server restart /
# OOM) is reported here instead of as cryptic "database is starting up" errors
# in the verify step below. No ON_ERROR_STOP: pg_dumpall's CREATE DATABASE lines
# harmlessly conflict with the init-script databases ("already exists").
if docker exec -i stargate-postgres psql -U "$POSTGRES_USER" -d postgres \
     < "$BACKUP_CONTENT/database/full_dump.sql" > /tmp/stargate-restore.log 2>&1; then
  grep -vE 'already exists|^CREATE' /tmp/stargate-restore.log | head -20 || true
  echo "  ✓ Database restore completed"
  rm -f /tmp/stargate-restore.log
else
  echo "  ✗ ERROR: PostgreSQL restore failed -- the server likely restarted or"
  echo "    ran out of memory mid-restore. Last lines of output:"
  tail -20 /tmp/stargate-restore.log
  rm -f /tmp/stargate-restore.log
  exit 1
fi
echo ""

# Verify databases exist
echo "Verifying databases..."
MISSING_DBS=0
for DB in smimekeys_client policy irisagent mxengine dashboard keycloak stalwart; do
  if docker exec stargate-postgres psql -U "$POSTGRES_USER" -lqt | cut -d \| -f 1 | grep -qw "$DB"; then
    echo "  ✓ $DB exists"
  else
    echo "  ✗ $DB missing"
    MISSING_DBS=$((MISSING_DBS + 1))
  fi
done
# The full-dump restore pipes through `head`, so its exit status can't be
# trusted; treat a missing expected DB as a hard restore failure instead of
# printing a green checkmark over lost data.
if [ "$MISSING_DBS" -gt 0 ]; then
  echo ""
  echo "ERROR: $MISSING_DBS expected database(s) missing after restore — the full dump did not apply cleanly."
  echo "  Inspect the restore output above and $BACKUP_CONTENT/database/full_dump.sql"
  exit 1
fi
echo ""

# ==============================================================================
# 9. Handle Vault (initialize fresh or unseal existing, then restore secrets)
# ==============================================================================
echo "============================================"
echo "  9. Setting up Vault"
echo "============================================"
echo ""

# vault-init is idempotent: it initializes a fresh Vault, or unseals an existing
# one using the restored vault-keys.json. Running it unconditionally keeps all
# init/unseal logic in one place (init-vault.sh, reached over the docker network
# -- Vault's 8200 port is not published to the host) and ensures the token sync
# and secret restore below run on every path, not only on a fresh install.
#
# Detached + `docker wait` captures the init container's exit code; compose's
# `depends_on: vault (service_healthy)` makes vault-init wait for Vault first.
echo "Initializing / unsealing Vault via vault-init..."
docker compose up -d vault-init

VAULT_INIT_EXIT=$(docker wait stargate-vault-init 2>/dev/null) || VAULT_INIT_EXIT=1
if [ "$VAULT_INIT_EXIT" != "0" ]; then
  echo "  ✗ vault-init exited with code $VAULT_INIT_EXIT"
  echo "    Check logs: docker compose logs vault-init"
  exit 1
fi

if [ ! -f "$SECRETS_DIR/vault-keys.json" ]; then
  echo "  ✗ ERROR: vault-keys.json not found after vault-init"
  exit 1
fi

# vault-init may have generated a fresh token (fresh VM) or kept the restored
# one; sync whatever is current into .env and customer-config.sh.
ROOT_TOKEN=$(jq -r '.root_token' "$SECRETS_DIR/vault-keys.json")
echo "  ✓ Vault ready"
sed -i "s/^VAULT_TOKEN=.*/VAULT_TOKEN=\"$ROOT_TOKEN\"/" "$ENV_FILE"
if grep -q '^VAULT_TOKEN=' "$CONFIG_FILE"; then
  sed -i "s|^VAULT_TOKEN=.*|VAULT_TOKEN=\"$ROOT_TOKEN\"|" "$CONFIG_FILE"
else
  echo "" >> "$CONFIG_FILE"
  echo "VAULT_TOKEN=\"$ROOT_TOKEN\"" >> "$CONFIG_FILE"
fi
echo "  ✓ Vault token synced to .env and customer-config.sh"

# -----------------------------------------------------------------
# Restore Vault KV secrets from backup (runs on every path)
# -----------------------------------------------------------------
if [ -d "$BACKUP_CONTENT/vault" ]; then
  echo ""
  echo "  Restoring Vault secrets from backup..."
  RESTORED_SECRETS=0
  for mount_dir in "$BACKUP_CONTENT/vault"/*/; do
    [ -d "$mount_dir" ] || continue
    mount_name=$(basename "$mount_dir")
    echo "    Restoring: $mount_name..."
    for secret_file in "$mount_dir"*.json; do
      [ -f "$secret_file" ] || continue
      key_name=$(basename "$secret_file" .json)
      SECRET_DATA=$(jq -r '.data.data // empty' "$secret_file" 2>/dev/null)
      if [ -n "$SECRET_DATA" ]; then
        if echo "$SECRET_DATA" | docker exec -i -e VAULT_TOKEN="$ROOT_TOKEN" stargate-vault \
          vault kv put -address=http://127.0.0.1:8200 "$mount_name/$key_name" - > /dev/null 2>&1; then
          echo "      ✓ $key_name"
          ((RESTORED_SECRETS++)) || true
        else
          echo "      ✗ Failed to restore $key_name"
        fi
      fi
    done
  done
  if [ "$RESTORED_SECRETS" -gt 0 ]; then
    echo ""
    echo "  ✓ $RESTORED_SECRETS Vault secrets restored"
  fi
else
  echo ""
  echo "  ⚠ No Vault secrets in backup (older backup format)"
  echo "    S/MIME keys and other secrets will need to be regenerated"
fi
echo ""

# ==============================================================================
# 9b. Restore MinIO objects (message archives, irisagent objects)
# ==============================================================================
echo "============================================"
echo "  Restoring MinIO objects"
echo "============================================"
echo ""

MC_IMAGE="minio/mc:RELEASE.2025-08-13T08-35-41Z"
if [ -d "$BACKUP_CONTENT/minio/${S3_BUCKET_NAME}" ]; then
  # Mirror objects back via a throwaway mc container sharing minio's network
  # namespace; mc mirror recreates the destination bucket if needed. (minio-init
  # in section 10 re-applies the bucket's anonymous-download policy afterwards.)
  if docker run --rm --network "container:stargate-minio" \
      -e "MC_HOST_local=http://${MINIO_ROOT_USER}:${MINIO_ROOT_PASSWORD}@127.0.0.1:9000" \
      -v "$BACKUP_CONTENT/minio:/backup" \
      "$MC_IMAGE" mirror --quiet --overwrite "/backup/${S3_BUCKET_NAME}" "local/${S3_BUCKET_NAME}"; then
    echo "  ✓ MinIO objects restored"
  else
    echo "  ✗ WARNING: MinIO restore failed (archived objects may be missing)"
  fi
else
  echo "  - No MinIO objects in backup; skipping"
fi
echo ""

# ==============================================================================
# 10. Start Application Services
# ==============================================================================
echo "============================================"
echo "  10. Starting Application Services"
echo "============================================"
echo ""

# Install and enable the systemd unit, then start the stack through it
# (`enable --now` runs start.sh). This both brings everything up now and makes
# the stack auto-start on boot, so the post-restore state matches the boot
# state instead of relying on a one-off `docker compose up -d`.
setup_systemd_service

echo ""
echo "Waiting for services to initialize..."
sleep 10

# ==============================================================================
# 11. Verify Services
# ==============================================================================
echo "============================================"
echo "  11. Verifying Services"
echo "============================================"
echo ""

docker compose ps

echo ""

# Check service health
SERVICES=("smimekeys-client:8081" "policy:8082" "irisagent:8083" "mxengine:8084")
echo "Service health checks:"
for svc in "${SERVICES[@]}"; do
  NAME="${svc%%:*}"
  PORT="${svc##*:}"
  if curl -s "http://localhost:$PORT/liveness" > /dev/null 2>&1; then
    echo "  ✓ $NAME is healthy"
  else
    echo "  - $NAME not responding (may still be starting)"
  fi
done
echo ""

# ==============================================================================
# Cleanup
# ==============================================================================
rm -rf "$RESTORE_DIR"

# ==============================================================================
# Summary
# ==============================================================================
echo ""
echo "============================================"
echo "  Restore Complete!"
echo "============================================"
echo ""
echo "  Customer: $CUSTOMER_NAME"
echo "  Deployment: $DEPLOYMENT_NAME"
echo ""
echo "  What was restored:"
echo "  ------------------"
echo "  ✓ Customer configuration"
echo "  ✓ Database (all tables and data)"
echo "  ✓ Vault keys"
if [ -d "$BACKUP_CONTENT/vault" ]; then
  echo "  ✓ Vault secrets (S/MIME keys, WG keys, etc.)"
fi
if [ $CERT_COUNT -gt 0 ]; then
  echo "  ✓ S/MIME certificates ($CERT_COUNT files)"
fi
if [ -n "$WG_PRIVATE_KEY" ]; then
  echo "  ✓ WireGuard private key"
fi
echo ""
echo "  Service URLs:"
echo "  -------------"
echo "  smimekeys-client:  http://localhost:8081"
echo "  policy:            http://localhost:8082"
echo "  irisagent:         http://localhost:8083"
echo "  mxengine:          http://localhost:8084"
echo ""
echo "  Service management:"
echo "  -------------------"
echo "  The 'stargate' systemd unit is enabled (auto-starts on boot)."
echo "  systemctl {start|stop|status|restart} stargate"
echo "  ./scripts/start.sh  |  ./scripts/stop.sh"
echo ""
echo "  If services show errors, wait a minute and check:"
echo "    docker compose logs -f <service-name>"
echo ""
