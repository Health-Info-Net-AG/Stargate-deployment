#!/bin/bash
# =============================================================================
# Throwaway roundtrip test: backup.sh must read config/secrets/TLS from
# /var/data and write its archive under /var/data/backups (never under the
# read-only docker-compose/ tree).
#
# backup.sh hard-requires a running `stargate-postgres` container (it's a
# fatal check, not a soft warning), so this spins up a disposable postgres
# container under that exact name, points STARGATE_DATA_DIR at a scratch
# root, runs the real backup.sh against it, and verifies:
#   1. the archive lands under $STARGATE_DATA_DIR/backups (not docker-compose/)
#   2. the archive actually contains the config/secrets files that were
#      written under $STARGATE_DATA_DIR/vereign -- proving backup.sh really
#      read them from the relocated paths (paths.sh), not stale PROJECT_DIR
#      ones (which would be empty/absent and produce an archive missing them).
# =============================================================================
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "$here/../docker-compose/scripts" && pwd)"
root=/tmp/sg-br-test; rm -rf "$root"
export STARGATE_DATA_DIR="$root"

PG_CONTAINER="stargate-postgres"

extract_dir=""
cleanup() {
  docker rm -f "$PG_CONTAINER" >/dev/null 2>&1 || true
  rm -rf "$root" "${extract_dir:-}" 2>/dev/null || true
}
trap cleanup EXIT

if docker ps -a --format '{{.Names}}' | grep -qx "$PG_CONTAINER"; then
  echo "ERROR: a container named $PG_CONTAINER already exists -- refusing to touch it. Remove it and re-run." >&2
  exit 1
fi

bash "$SCRIPTS_DIR/init-data-layout.sh"
printf 'VAULT_TOKEN="t"\nPOSTGRES_PASSWORD="p"\nWG_PRIVATE_KEY="k"\n' > "$root/vereign/customer-config.sh"
printf 'POSTGRES_USER=postgres\nPOSTGRES_PASSWORD=p\n' > "$root/vereign/.env"
echo dummy > "$root/vereign/secrets/vault-keys.json"
# A site NTP override lives on the Data Disk precisely so it travels in the archive --
# nothing under /etc does. init-data-layout.sh created the directory above.
printf 'pool ntp.test.local iburst\n' > "$root/vereign/chrony/ntp.sources"

echo "Starting throwaway $PG_CONTAINER container..."
docker run -d --name "$PG_CONTAINER" \
  -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=p \
  -e POSTGRES_HOST_AUTH_METHOD=trust \
  postgres:18-alpine >/dev/null

echo "Waiting for postgres to be ready..."
pg_ready=false
for _ in $(seq 1 30); do
  if docker exec "$PG_CONTAINER" pg_isready -U postgres >/dev/null 2>&1; then
    pg_ready=true
    break
  fi
  sleep 1
done
[ "$pg_ready" = true ] || { echo "postgres never became ready"; exit 1; }

# backup.sh must place its archive under $root/backups (not under docker-compose/)
bash "$SCRIPTS_DIR/backup.sh" >/dev/null 2>&1 || { echo "backup failed"; exit 1; }

ARCHIVE=$(ls "$root"/backups/*.tar.gz 2>/dev/null | head -1) || true
[ -n "$ARCHIVE" ] || { echo "no backup archive under \$STARGATE_DATA_DIR/backups"; exit 1; }

# Also fail if backup.sh regressed to writing under docker-compose/ in addition
# to (or instead of) $STARGATE_DATA_DIR/backups (a pre-existing empty backups/
# dir under the compose tree is fine -- only new archive content is a bug).
if ls "$SCRIPTS_DIR"/../backups/*.tar.gz >/dev/null 2>&1 || ls "$SCRIPTS_DIR"/backups/*.tar.gz >/dev/null 2>&1; then
  echo "found a backup archive under docker-compose/ -- archive must only land under \$STARGATE_DATA_DIR/backups"
  exit 1
fi

extract_dir=$(mktemp -d)
tar -xzf "$ARCHIVE" -C "$extract_dir"
CONTENT_DIR=$(find "$extract_dir" -mindepth 1 -maxdepth 1 -type d | head -1)

# Prove backup.sh actually read from the relocated paths (paths.sh), not a
# stale $PROJECT_DIR one: the archived customer-config.sh/.env/vault-keys.json
# must match what was written under $root/vereign, not be missing/empty.
grep -q 'VAULT_TOKEN="t"' "$CONTENT_DIR/config/customer-config.sh" \
  || { echo "archived customer-config.sh does not match \$STARGATE_DATA_DIR/vereign/customer-config.sh"; exit 1; }
grep -q 'POSTGRES_USER=postgres' "$CONTENT_DIR/config/.env" \
  || { echo "archived .env does not match \$STARGATE_DATA_DIR/vereign/.env"; exit 1; }
[ -f "$CONTENT_DIR/secrets/vault-keys.json" ] \
  || { echo "vault-keys.json missing from archive"; exit 1; }
grep -q 'pool ntp.test.local iburst' "$CONTENT_DIR/config/ntp.sources" \
  || { echo "ntp.sources missing from archive -- a site's NTP override would not survive a rebuild"; exit 1; }

echo "PASS"
