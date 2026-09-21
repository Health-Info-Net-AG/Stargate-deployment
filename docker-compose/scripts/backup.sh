#!/bin/bash
set -eo pipefail

# Usage: backup.sh [--label NAME]
#   --label NAME   Append NAME to the backup's directory/archive name, e.g.
#                  "v0.5.0-pre_update" (used by update.sh before a --release
#                  jump so the backup is identifiable at a glance). Sanitized
#                  to filesystem-safe characters. Purely cosmetic -- restore.sh
#                  treats the archive name as an opaque path either way.
LABEL=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --label)
      LABEL="${2:-}"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [--label NAME]"
      exit 1
      ;;
  esac
done
# Keep only filesystem-safe characters.
LABEL="$(printf '%s' "$LABEL" | tr -c 'A-Za-z0-9._-' '_')"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC2034 # required by lib/paths.sh's calling convention (used by its compose() helper), unused directly here
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
. "$SCRIPT_DIR/lib/paths.sh"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
# BACKUP_NAME is TIMESTAMP, optionally suffixed with the label -- used for both
# the working subdirectory and the final archive, so a labeled backup is
# identifiable by filename alone while still sorting chronologically.
BACKUP_NAME="$TIMESTAMP"
[ -n "$LABEL" ] && BACKUP_NAME="${TIMESTAMP}_${LABEL}"
BACKUP_SUBDIR="$BACKUP_DIR/$BACKUP_NAME"

# read_env_var() reads one KEY from .env without sourcing the file (Compose
# .env values may be unquoted and would break `source` under `set -e`). We only
# need POSTGRES_USER, POSTGRES_PASSWORD and VAULT_TOKEN here.
. "$SCRIPT_DIR/lib/env.sh"
. "$SCRIPT_DIR/lib/vault-tokens.sh"  # needs SECRETS_DIR/ENV_FILE from paths.sh

if [ -f "$ENV_FILE" ]; then
  POSTGRES_USER=$(read_env_var POSTGRES_USER "$ENV_FILE")
  POSTGRES_PASSWORD=$(read_env_var POSTGRES_PASSWORD "$ENV_FILE")
  VAULT_TOKEN=$(read_env_var VAULT_TOKEN_BACKUP "$ENV_FILE")
  S3_ACCESS_KEY=$(read_env_var S3_ACCESS_KEY "$ENV_FILE")
  S3_SECRET_KEY=$(read_env_var S3_SECRET_KEY "$ENV_FILE")
  S3_BUCKET_NAME=$(read_env_var S3_BUCKET_NAME "$ENV_FILE")
fi

POSTGRES_USER="${POSTGRES_USER:-postgres}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-postgres}"
S3_ACCESS_KEY="${S3_ACCESS_KEY:-minioadmin}"
S3_SECRET_KEY="${S3_SECRET_KEY:-minioadmin}"
S3_BUCKET_NAME="${S3_BUCKET_NAME:-stargate-bucket}"
# Pinned aws-cli image used for S3 object backup/restore.
AWS_CLI_IMAGE="amazon/aws-cli:2.27.31"

echo "============================================"
echo "  Stargate Full Backup"
echo "============================================"
echo ""
echo "Timestamp: $TIMESTAMP"
[ -n "$LABEL" ] && echo "Label: $LABEL"
echo "Backup directory: $BACKUP_SUBDIR"
echo ""

# Check if postgres container is running
if ! docker ps --format '{{.Names}}' | grep -q "stargate-postgres"; then
  echo "ERROR: stargate-postgres container is not running."
  echo "Start the services first: ./scripts/start.sh"
  exit 1
fi

# Create backup directory structure. umask 077 first: $BACKUP_DIR is
# world-readable, and the staging tree holds the Vault unseal keys, root token,
# WG private key and KV secrets in clear text until the archive is rolled up
# below. Without this they sit at 0644 for the duration of the backup.
umask 077
mkdir -p "$BACKUP_SUBDIR/secrets"
mkdir -p "$BACKUP_SUBDIR/config"
mkdir -p "$BACKUP_SUBDIR/database"

# ==============================================================================
# 1. Database Backup - Full dump of all databases
# ==============================================================================
echo "============================================"
echo "  1. Backing up PostgreSQL (all databases)"
echo "============================================"
echo ""

echo "Creating full database dump..."
# Test the command directly: under `set -e` a separate `if [ $? -eq 0 ]` check
# is dead code (a failure would abort before it runs). Putting the command in
# the `if` both suppresses set -e for it and makes the error path reachable.
if docker exec stargate-postgres pg_dumpall -U "$POSTGRES_USER" > "$BACKUP_SUBDIR/database/full_dump.sql"; then
  DUMP_SIZE=$(du -h "$BACKUP_SUBDIR/database/full_dump.sql" | cut -f1)
  echo "  ✓ Full database dump created ($DUMP_SIZE)"
else
  echo "  ✗ Failed to create database dump"
  exit 1
fi

# Also create individual dumps for easier partial restore if needed
echo ""
echo "Creating individual database dumps..."
DATABASES=("smimekeys_client" "policy" "irisagent" "mxengine" "idagent" "idagent_keri" "dashboard" "keycloak" "stalwart")
for DB in "${DATABASES[@]}"; do
  echo "  Backing up: $DB..."
  docker exec stargate-postgres pg_dump -U "$POSTGRES_USER" "$DB" > "$BACKUP_SUBDIR/database/${DB}.sql" 2>/dev/null || true
  if [ -s "$BACKUP_SUBDIR/database/${DB}.sql" ]; then
    echo "    ✓ $DB backed up"
  else
    echo "    - $DB (empty or not found)"
    rm -f "$BACKUP_SUBDIR/database/${DB}.sql"
  fi
done

# ==============================================================================
# 2. Vault Keys Backup
# ==============================================================================
echo ""
echo "============================================"
echo "  2. Backing up Vault Keys"
echo "============================================"
echo ""

VAULT_KEYS_FILE="$SECRETS_DIR/vault-keys.json"
if [ -f "$VAULT_KEYS_FILE" ]; then
  cp "$VAULT_KEYS_FILE" "$BACKUP_SUBDIR/secrets/"
  echo "  ✓ vault-keys.json backed up"
else
  echo "  ✗ WARNING: vault-keys.json not found!"
  echo "    Vault will need to be reinitialized on restore."
fi

# ==============================================================================
# 3. Customer Configuration Backup
# ==============================================================================
echo ""
echo "============================================"
echo "  3. Backing up Customer Configuration"
echo "============================================"
echo ""

if [ -f "$CONFIG_FILE" ]; then
  cp "$CONFIG_FILE" "$BACKUP_SUBDIR/config/"
  echo "  ✓ customer-config.sh backed up"
  
  # Check if WireGuard key is included
  if grep -q 'WG_PRIVATE_KEY="[^"]\+"' "$CONFIG_FILE"; then
    echo "    (includes WireGuard private key)"
  else
    echo "    WARNING: WireGuard private key not set in config"
  fi
else
  echo "  ✗ WARNING: customer-config.sh not found!"
fi

# Also backup .env for reference (contains generated values)
if [ -f "$ENV_FILE" ]; then
  cp "$ENV_FILE" "$BACKUP_SUBDIR/config/"
  echo "  ✓ .env backed up (for reference)"
fi

# Operator NTP sources, if the site overrode the shipped default. Host-level config
# (chronyd reads it directly), but it lives on the Data Disk precisely so it travels
# in the backup -- nothing under /etc survives a rebuild.
if [ -f "$CHRONY_SOURCES_FILE" ]; then
  cp "$CHRONY_SOURCES_FILE" "$BACKUP_SUBDIR/config/"
  echo "  ✓ ntp.sources backed up (custom NTP servers)"
fi

# ==============================================================================
# 4. S/MIME Keys and Certificates Backup
# ==============================================================================
echo ""
echo "============================================"
echo "  4. Backing up S/MIME Keys & Certificates"
echo "============================================"
echo ""

# Backup CSR
if [ -f "$SECRETS_DIR/signing-key.csr" ]; then
  cp "$SECRETS_DIR/signing-key.csr" "$BACKUP_SUBDIR/secrets/"
  echo "  ✓ signing-key.csr backed up"
fi

# Backup any certificates (*.crt, *.pem, *.cer)
CERT_COUNT=0
for cert in "$SECRETS_DIR"/*.crt "$SECRETS_DIR"/*.pem "$SECRETS_DIR"/*.cer; do
  if [ -f "$cert" ]; then
    cp "$cert" "$BACKUP_SUBDIR/secrets/"
    echo "  ✓ $(basename "$cert") backed up"
    ((CERT_COUNT++)) || true
  fi
done

if [ $CERT_COUNT -eq 0 ]; then
  echo "  - No certificates found (CSR may not be signed yet)"
fi

# Backup TLS certificates (Caddy)
if [ -d "$TLS_DIR" ] && [ "$(ls -A "$TLS_DIR" 2>/dev/null)" ]; then
  mkdir -p "$BACKUP_SUBDIR/config/caddy-ssl"
  cp "$TLS_DIR"/* "$BACKUP_SUBDIR/config/caddy-ssl/"
  echo "  ✓ TLS certificates (Caddy) backed up"
else
  echo "  - No TLS certificates found in $TLS_DIR"
fi

# ==============================================================================
# 5. Vault Secrets Backup
# ==============================================================================
echo ""
echo "============================================"
echo "  5. Backing up Vault Secrets"
echo "============================================"
echo ""

mkdir -p "$BACKUP_SUBDIR/vault"

# The backup token covers the secret-* mounts.
VAULT_TOKEN="${VAULT_TOKEN:-}"
if [ -z "$VAULT_TOKEN" ]; then
  VAULT_TOKEN=$(service_token VAULT_TOKEN_BACKUP 2>/dev/null || echo "")
fi
export VAULT_TOKEN

VAULT_BACKUP_INCOMPLETE=false
VAULT_ERR=$(mktemp)
trap 'rm -f "$VAULT_ERR"' EXIT

if [ -z "$VAULT_TOKEN" ]; then
  echo "  ✗ WARNING: No Vault token available!"
  echo "    Vault secrets will NOT be backed up."
  VAULT_SECRETS_COUNT=0
  VAULT_BACKUP_INCOMPLETE=true
else
  # Check if Vault is accessible
  if ! docker exec stargate-vault vault status -address=http://127.0.0.1:8200 > /dev/null 2>&1; then
    echo "  ✗ WARNING: Vault is not accessible!"
    echo "    Vault secrets will NOT be backed up."
    VAULT_SECRETS_COUNT=0
    VAULT_BACKUP_INCOMPLETE=true
  else
    VAULT_SECRETS_COUNT=0
    
    # List of KV mounts to backup
    VAULT_MOUNTS=("secret-smimekeys-client" "secret-irisagent" "secret-policy" "secret-mxengine" "secret-mtaconf" "secret-idagent" "secret-mailauth")
    
    for mount in "${VAULT_MOUNTS[@]}"; do
      echo "  Backing up: $mount..."
      
      # List all keys in the mount. `kv list` exits 2 both for an empty mount and
      # for a refusal, so the stderr text is what separates "nothing here" from
      # "not allowed" -- treating the second as the first would silently write an
      # incomplete archive.
      : > "$VAULT_ERR"
      KEYS=$(docker exec -e VAULT_TOKEN stargate-vault \
        vault kv list -address=http://127.0.0.1:8200 -format=json "$mount" 2>"$VAULT_ERR") || KEYS=""

      if grep -qiE 'permission denied|403' "$VAULT_ERR"; then
        echo "    ✗ ERROR: permission denied listing $mount"
        VAULT_BACKUP_INCOMPLETE=true
        continue
      fi

      if [ "$KEYS" = "[]" ] || [ -z "$KEYS" ]; then
        echo "    - No secrets found"
        continue
      fi
      
      # Create mount directory
      mkdir -p "$BACKUP_SUBDIR/vault/$mount"
      
      # Export each secret
      for key in $(echo "$KEYS" | jq -r '.[]' 2>/dev/null); do
        # Skip directory entries (ending with /)
        if [[ "$key" == */ ]]; then
          continue
        fi
        
        # Get the secret data
        : > "$VAULT_ERR"
        SECRET_DATA=$(docker exec -e VAULT_TOKEN stargate-vault \
          vault kv get -address=http://127.0.0.1:8200 -format=json "$mount/$key" 2>"$VAULT_ERR") || SECRET_DATA=""

        if grep -qiE 'permission denied|403' "$VAULT_ERR"; then
          echo "    ✗ ERROR: permission denied reading $mount/$key"
          VAULT_BACKUP_INCOMPLETE=true
          continue
        fi

        if [ -n "$SECRET_DATA" ] && [ "$SECRET_DATA" != "{}" ]; then
          echo "$SECRET_DATA" > "$BACKUP_SUBDIR/vault/$mount/${key}.json"
          echo "    ✓ $key"
          ((VAULT_SECRETS_COUNT++)) || true
        elif [ -s "$VAULT_ERR" ]; then
          echo "    ✗ ERROR: could not read $mount/$key"
          VAULT_BACKUP_INCOMPLETE=true
        else
          # Listed but no current version: a soft-deleted key, not a failure.
          echo "    - $key (no current version)"
        fi
      done
    done
    
    if [ $VAULT_SECRETS_COUNT -gt 0 ]; then
      echo ""
      echo "  ✓ $VAULT_SECRETS_COUNT Vault secrets backed up"
    else
      echo "  - No Vault secrets found to backup"
    fi
  fi
fi

# ==============================================================================
# 6. MinIO Object Storage (message archives, irisagent objects)
# ==============================================================================
echo ""
echo "============================================"
echo "  6. Backing up S3 objects"
echo "============================================"
echo ""

S3_OBJ_COUNT=0
mkdir -p "$BACKUP_SUBDIR/s3"
if docker ps --format '{{.Names}}' | grep -q "stargate-seaweedfs"; then
  # Sync the bucket out via a throwaway aws-cli container that shares the
  # seaweedfs container's network namespace, so 127.0.0.1:8333 reaches it
  # without depending on the bridge-network name.
  if docker run --rm --network "container:stargate-seaweedfs" \
      -e "AWS_ACCESS_KEY_ID=${S3_ACCESS_KEY}" \
      -e "AWS_SECRET_ACCESS_KEY=${S3_SECRET_KEY}" \
      -e "AWS_DEFAULT_REGION=us-east-1" \
      -v "$BACKUP_SUBDIR/s3:/backup" \
      "$AWS_CLI_IMAGE" s3 sync --quiet \
      --endpoint-url http://127.0.0.1:8333 \
      "s3://${S3_BUCKET_NAME}" "/backup/${S3_BUCKET_NAME}"; then
    S3_OBJ_COUNT=$(find "$BACKUP_SUBDIR/s3" -type f 2>/dev/null | wc -l)
    echo "  ✓ S3 bucket '${S3_BUCKET_NAME}' backed up ($S3_OBJ_COUNT objects)"
  else
    echo "  ✗ WARNING: S3 backup failed (objects will not be in this archive)"
  fi
else
  echo "  - SeaweedFS container not running; skipping object backup"
fi

# ==============================================================================
# 7. Create Backup Manifest
# ==============================================================================
echo ""
echo "============================================"
echo "  7. Creating Backup Manifest"
echo "============================================"
echo ""

cat > "$BACKUP_SUBDIR/manifest.json" << EOF
{
  "backup_version": "2.0",
  "timestamp": "$TIMESTAMP",
  "label": "$LABEL",
  "created_at": "$(date -Iseconds)",
  "hostname": "$(hostname)",
  "source_app_version": "$(detect_app_version "$PROJECT_DIR")",
  "contents": {
    "database": {
      "full_dump": true,
      "individual_dumps": $(ls "$BACKUP_SUBDIR/database"/*.sql 2>/dev/null | wc -l)
    },
    "vault_keys": $([ -f "$BACKUP_SUBDIR/secrets/vault-keys.json" ] && echo "true" || echo "false"),
    "vault_secrets": ${VAULT_SECRETS_COUNT:-0},
    "customer_config": $([ -f "$BACKUP_SUBDIR/config/customer-config.sh" ] && echo "true" || echo "false"),
    "smime_csr": $([ -f "$BACKUP_SUBDIR/secrets/signing-key.csr" ] && echo "true" || echo "false"),
    "certificates": $CERT_COUNT,
    "s3_objects": ${S3_OBJ_COUNT:-0}
  }
}
EOF

echo "  ✓ manifest.json created"

# ==============================================================================
# 8. Create Compressed Archive
# ==============================================================================
echo ""
echo "============================================"
echo "  8. Creating Compressed Archive"
echo "============================================"
echo ""

cd "$BACKUP_DIR"
tar -czf "${BACKUP_NAME}.tar.gz" "$BACKUP_NAME"
# The archive contains Vault unseal keys/root token, KV secrets, and the WG
# private key -- restrict it to the owner (it is not encrypted).
chmod 600 "${BACKUP_NAME}.tar.gz"
rm -rf "$BACKUP_NAME"

ARCHIVE_PATH="$BACKUP_DIR/${BACKUP_NAME}.tar.gz"
ARCHIVE_SIZE=$(du -h "$ARCHIVE_PATH" | cut -f1)

echo "  ✓ Archive created"

# ==============================================================================
# Summary
# ==============================================================================
echo ""
echo "============================================"
echo "  Backup Complete"
echo "============================================"
echo ""
echo "  Archive: $ARCHIVE_PATH"
echo "  Size: $ARCHIVE_SIZE"
echo ""
echo "  Contents:"
echo "  ---------"
echo "  • Full PostgreSQL dump (all databases)"
echo "  • Individual database dumps"
echo "  • Vault unseal keys and tokens"
echo "  • Vault KV secrets (S/MIME keys, WG keys, etc.)"
echo "  • Customer configuration (with WireGuard key)"
echo "  • S/MIME CSR and certificates"
echo ""
echo "  To restore on a new machine:"
echo "  ----------------------------"
echo "  1. Copy this archive to the new machine"
echo "  2. Run: ./scripts/restore.sh ${BACKUP_NAME}.tar.gz"
echo ""

# ==============================================================================
# Cleanup old backups (keep last 7 days)
# ==============================================================================
echo "Cleaning up backups older than 7 days..."
find "$BACKUP_DIR" -name "*.tar.gz" -type f -mtime +7 -delete 2>/dev/null || true
echo "Done."
echo ""

# Secrets are missing from an archive that otherwise looks complete. It is kept
# -- a partial backup still beats none -- but the exit code has to say so, or
# cron reports success over missing keys.
if [ "$VAULT_BACKUP_INCOMPLETE" = true ]; then
  echo "ERROR: the Vault section of this archive is INCOMPLETE (see above)." >&2
  echo "  $ARCHIVE_PATH exists but must not be relied on for recovery." >&2
  exit 1
fi
