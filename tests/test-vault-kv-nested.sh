#!/bin/bash
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "$here/../docker-compose/scripts" && pwd)"
VAULT_IMAGE="$(grep -m1 -oE 'hashicorp/vault:[^" ]+' "$here/../docker-compose/docker-compose.yml")"

fail() { echo "FAIL: $*"; exit 1; }

if docker ps -a --format '{{.Names}}' | grep -qx stargate-vault; then
  echo "ERROR: a container named stargate-vault already exists -- refusing to touch it. Remove it and re-run." >&2
  exit 1
fi

work="$(mktemp -d)"
cleanup() {
  docker rm -f stargate-vault > /dev/null 2>&1 || true
  rm -rf "$work"
}
trap cleanup EXIT

docker run -d --name stargate-vault -e VAULT_DEV_ROOT_TOKEN_ID=root "$VAULT_IMAGE" > /dev/null
export VAULT_TOKEN=root

vx() { docker exec -i -e VAULT_TOKEN -e VAULT_ADDR=http://127.0.0.1:8200 stargate-vault vault "$@"; }

for _ in $(seq 1 30); do
  vx status > /dev/null 2>&1 && break
  sleep 1
done
vx status > /dev/null 2>&1 || fail "dev Vault did not come up"

MOUNTS="secret-mtaconf secret-mailauth"
for m in $MOUNTS; do vx secrets enable -path="$m" kv-v2 > /dev/null; done
vx kv put secret-mtaconf/flat-key value=flat > /dev/null
vx kv put secret-mtaconf/stalwart/tls-key/2f0c9a1e pem=tls-pem > /dev/null
vx kv put secret-mailauth/dkim/example.com/sel1 private_key=dkim-key > /dev/null
vx kv put secret-mailauth/arc/example.com/sel1 private_key=arc-key > /dev/null

. "$SCRIPTS_DIR/lib/vault-kv.sh"

VAULT_ERR="$work/err"
VAULT_SECRETS_COUNT=0
VAULT_BACKUP_INCOMPLETE=false
for m in $MOUNTS; do
  vault_kv_backup_path "$m" "" "$work/vault/$m" >> "$work/backup.log"
done

[ "$VAULT_BACKUP_INCOMPLETE" = false ] || fail "backup marked incomplete: $(cat "$work/backup.log")"
[ "$VAULT_SECRETS_COUNT" -eq 4 ] || fail "expected 4 secrets backed up, got $VAULT_SECRETS_COUNT"
for f in secret-mtaconf/flat-key secret-mtaconf/stalwart/tls-key/2f0c9a1e \
         secret-mailauth/dkim/example.com/sel1 secret-mailauth/arc/example.com/sel1; do
  [ -s "$work/vault/$f.json" ] || fail "missing from backup: $f.json"
done

for m in $MOUNTS; do
  vx secrets disable "$m" > /dev/null
  vx secrets enable -path="$m" kv-v2 > /dev/null
done
vx kv get secret-mtaconf/stalwart/tls-key/2f0c9a1e > /dev/null 2>&1 && fail "mount was not emptied before restore"

RESTORED_SECRETS=0
for d in "$work/vault"/*/; do
  vault_kv_restore_mount_dir "$d" >> "$work/restore.log"
done

[ "$RESTORED_SECRETS" -eq 4 ] || fail "expected 4 secrets restored, got $RESTORED_SECRETS: $(cat "$work/restore.log")"
[ "$(vx kv get -field=value secret-mtaconf/flat-key)" = flat ] || fail "flat secret not restored"
[ "$(vx kv get -field=pem secret-mtaconf/stalwart/tls-key/2f0c9a1e)" = tls-pem ] || fail "nested TLS key not restored"
[ "$(vx kv get -field=private_key secret-mailauth/dkim/example.com/sel1)" = dkim-key ] || fail "nested DKIM key not restored"
[ "$(vx kv get -field=private_key secret-mailauth/arc/example.com/sel1)" = arc-key ] || fail "nested ARC key not restored"

vx secrets disable secret-mailauth > /dev/null
RESTORED_SECRETS=0
VAULT_RESTORE_FAILED=0
vault_kv_restore_mount_dir "$work/vault/secret-mailauth/" >> "$work/restore.log"
[ "$VAULT_RESTORE_FAILED" -eq 2 ] || fail "expected 2 failed imports into a missing mount, got $VAULT_RESTORE_FAILED"
[ "$RESTORED_SECRETS" -eq 0 ] || fail "imports into a missing mount counted as restored"

echo "PASS"
