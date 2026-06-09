#!/bin/bash
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="$PROJECT_DIR/backups"
SECRETS_DIR="$PROJECT_DIR/secrets"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_SUBDIR="$BACKUP_DIR/$TIMESTAMP"

# read_env_var() reads one KEY from .env without sourcing the file (Compose
# .env values may be unquoted and would break `source` under `set -e`). We only
# need POSTGRES_USER, POSTGRES_PASSWORD and VAULT_TOKEN here.
. "$SCRIPT_DIR/lib/env.sh"

if [ -f "$PROJECT_DIR/.env" ]; then
  POSTGRES_USER=$(read_env_var POSTGRES_USER "$PROJECT_DIR/.env")
  POSTGRES_PASSWORD=$(read_env_var POSTGRES_PASSWORD "$PROJECT_DIR/.env")
  VAULT_TOKEN=$(read_env_var VAULT_TOKEN "$PROJECT_DIR/.env")
  MINIO_ROOT_USER=$(read_env_var MINIO_ROOT_USER "$PROJECT_DIR/.env")
  MINIO_ROOT_PASSWORD=$(read_env_var MINIO_ROOT_PASSWORD "$PROJECT_DIR/.env")
  S3_BUCKET_NAME=$(read_env_var S3_BUCKET_NAME "$PROJECT_DIR/.env")
fi

POSTGRES_USER="${POSTGRES_USER:-postgres}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-postgres}"
MINIO_ROOT_USER="${MINIO_ROOT_USER:-minioadmin}"
MINIO_ROOT_PASSWORD="${MINIO_ROOT_PASSWORD:-minioadmin}"
S3_BUCKET_NAME="${S3_BUCKET_NAME:-stargate-bucket}"
# Pinned mc image used for MinIO object backup/restore (matches docker-compose).
MC_IMAGE="minio/mc:RELEASE.2025-08-13T08-35-41Z"

echo "============================================"
echo "  Stargate Full Backup"
echo "============================================"
echo ""
echo "Timestamp: $TIMESTAMP"
echo "Backup directory: $BACKUP_SUBDIR"
echo ""

# Check if postgres container is running
if ! docker ps --format '{{.Names}}' | grep -q "stargate-postgres"; then
  echo "ERROR: stargate-postgres container is not running."
  echo "Start the services first: ./scripts/start.sh"
  exit 1
fi

# Create backup directory structure
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
DATABASES=("smimekeys_client" "policy" "irisagent" "mxengine" "dashboard" "keycloak" "stalwart")
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

CONFIG_FILE="$PROJECT_DIR/customer-config.sh"
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
if [ -f "$PROJECT_DIR/.env" ]; then
  cp "$PROJECT_DIR/.env" "$BACKUP_SUBDIR/config/"
  echo "  ✓ .env backed up (for reference)"
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
TLS_DIR="$PROJECT_DIR/config/caddy/ssl"
if [ -d "$TLS_DIR" ] && [ "$(ls -A "$TLS_DIR" 2>/dev/null)" ]; then
  mkdir -p "$BACKUP_SUBDIR/config/caddy-ssl"
  cp "$TLS_DIR"/* "$BACKUP_SUBDIR/config/caddy-ssl/"
  echo "  ✓ TLS certificates (Caddy) backed up"
else
  echo "  - No TLS certificates found in config/caddy/ssl/"
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

# Check if Vault is running and we have a token
VAULT_TOKEN="${VAULT_TOKEN:-}"
if [ -z "$VAULT_TOKEN" ] && [ -f "$SECRETS_DIR/vault-keys.json" ]; then
  VAULT_TOKEN=$(jq -r '.root_token' "$SECRETS_DIR/vault-keys.json" 2>/dev/null || echo "")
fi

if [ -z "$VAULT_TOKEN" ]; then
  echo "  ✗ WARNING: No Vault token available!"
  echo "    Vault secrets will NOT be backed up."
  VAULT_SECRETS_COUNT=0
else
  # Check if Vault is accessible
  if ! docker exec stargate-vault vault status -address=http://127.0.0.1:8200 > /dev/null 2>&1; then
    echo "  ✗ WARNING: Vault is not accessible!"
    echo "    Vault secrets will NOT be backed up."
    VAULT_SECRETS_COUNT=0
  else
    VAULT_SECRETS_COUNT=0
    
    # List of KV mounts to backup
    VAULT_MOUNTS=("secret-smimekeys-client" "secret-irisagent" "secret-policy" "secret-mxengine" "secret-mtaconf")
    
    for mount in "${VAULT_MOUNTS[@]}"; do
      echo "  Backing up: $mount..."
      
      # List all keys in the mount
      KEYS=$(docker exec -e VAULT_TOKEN="$VAULT_TOKEN" stargate-vault \
        vault kv list -address=http://127.0.0.1:8200 -format=json "$mount" 2>/dev/null || echo "[]")
      
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
        SECRET_DATA=$(docker exec -e VAULT_TOKEN="$VAULT_TOKEN" stargate-vault \
          vault kv get -address=http://127.0.0.1:8200 -format=json "$mount/$key" 2>/dev/null || echo "{}")
        
        if [ -n "$SECRET_DATA" ] && [ "$SECRET_DATA" != "{}" ]; then
          echo "$SECRET_DATA" > "$BACKUP_SUBDIR/vault/$mount/${key}.json"
          echo "    ✓ $key"
          ((VAULT_SECRETS_COUNT++)) || true
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
echo "  6. Backing up MinIO objects"
echo "============================================"
echo ""

MINIO_OBJ_COUNT=0
mkdir -p "$BACKUP_SUBDIR/minio"
if docker ps --format '{{.Names}}' | grep -q "stargate-minio"; then
  # Mirror the bucket out via a throwaway mc container that shares the minio
  # container's network namespace, so 127.0.0.1:9000 reaches it without
  # depending on the bridge-network name. MC_HOST_local carries the credentials.
  if docker run --rm --network "container:stargate-minio" \
      -e "MC_HOST_local=http://${MINIO_ROOT_USER}:${MINIO_ROOT_PASSWORD}@127.0.0.1:9000" \
      -v "$BACKUP_SUBDIR/minio:/backup" \
      "$MC_IMAGE" mirror --quiet --overwrite "local/${S3_BUCKET_NAME}" "/backup/${S3_BUCKET_NAME}"; then
    # Count under the always-present minio/ dir (an empty bucket leaves no
    # bucket subdir, and `find` on a missing path exits non-zero -> would abort
    # the script under `set -eo pipefail`).
    MINIO_OBJ_COUNT=$(find "$BACKUP_SUBDIR/minio" -type f 2>/dev/null | wc -l)
    echo "  ✓ MinIO bucket '${S3_BUCKET_NAME}' backed up ($MINIO_OBJ_COUNT objects)"
  else
    echo "  ✗ WARNING: MinIO backup failed (objects will not be in this archive)"
  fi
else
  echo "  - MinIO container not running; skipping object backup"
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
  "created_at": "$(date -Iseconds)",
  "hostname": "$(hostname)",
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
    "minio_objects": ${MINIO_OBJ_COUNT:-0}
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
tar -czf "${TIMESTAMP}.tar.gz" "$TIMESTAMP"
# The archive contains Vault unseal keys/root token, KV secrets, and the WG
# private key -- restrict it to the owner (it is not encrypted).
chmod 600 "${TIMESTAMP}.tar.gz"
rm -rf "$TIMESTAMP"

ARCHIVE_PATH="$BACKUP_DIR/${TIMESTAMP}.tar.gz"
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
echo "  2. Run: ./scripts/restore.sh ${TIMESTAMP}.tar.gz"
echo ""

# ==============================================================================
# Cleanup old backups (keep last 7 days)
# ==============================================================================
echo "Cleaning up backups older than 7 days..."
find "$BACKUP_DIR" -name "*.tar.gz" -type f -mtime +7 -delete 2>/dev/null || true
echo "Done."
echo ""
