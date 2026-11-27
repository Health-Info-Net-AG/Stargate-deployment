#!/bin/bash
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_DIR="$(cd "$here/../docker-compose" && pwd)"
COMPOSE_FILE="$COMPOSE_DIR/docker-compose.yml"
VAULT_IMAGE="$(grep -m1 -oE 'hashicorp/vault:[^" ]+' "$COMPOSE_FILE")"
INIT_IMAGE="$(grep -m1 -oE 'healthinfonetag/gateway-init:[^" ]+' "$COMPOSE_FILE")"

fail() { echo "FAIL: $*"; exit 1; }

run_id="t3570-$$"
net="$run_id-net"
secrets="$(mktemp -d)"
log="$(mktemp)"

cleanup() {
  docker rm -f "$run_id-vault" > /dev/null 2>&1 || true
  docker volume rm -f "$run_id-data1" "$run_id-data2" > /dev/null 2>&1 || true
  docker network rm "$net" > /dev/null 2>&1 || true
  docker run --rm -v "$secrets:/s" --entrypoint sh "$INIT_IMAGE" -c 'rm -rf /s/* /s/.[!.]*' > /dev/null 2>&1 || true
  rm -rf "$secrets" "$log"
}
trap cleanup EXIT

docker network create "$net" > /dev/null

start_vault() {
  docker rm -f "$run_id-vault" > /dev/null 2>&1 || true
  docker run --rm -v "$1:/d" --entrypoint sh "$INIT_IMAGE" -c 'chown 100:1000 /d'
  docker run -d --name "$run_id-vault" --network "$net" --network-alias vault --cap-add IPC_LOCK \
    -v "$COMPOSE_DIR/config/vault:/vault/config:ro" -v "$1:/vault/data" \
    "$VAULT_IMAGE" server > /dev/null
  local rc
  for _ in $(seq 1 30); do
    rc=0
    docker exec "$run_id-vault" vault status -address=http://127.0.0.1:8200 > /dev/null 2>&1 || rc=$?
    [ "$rc" -le 2 ] && return 0
    sleep 1
  done
  fail "Vault did not start"
}

run_init() {
  docker run --rm --network "$net" --user root \
    -e VAULT_ADDR=http://vault:8200 -e WG_PRIVATE_KEY= "$@" \
    -v "$COMPOSE_DIR/scripts:/scripts:ro" -v "$secrets:/secrets" \
    --entrypoint /scripts/init-vault.sh "$INIT_IMAGE" > "$log" 2>&1
}

in_secrets() { docker run --rm -v "$secrets:/s" --entrypoint sh "$INIT_IMAGE" -c "$1"; }
keys_sum() { in_secrets 'sha256sum /s/vault-keys.json 2>/dev/null | cut -d" " -f1'; }
keys_usable() { in_secrets 'jq -e ".root_token and (.unseal_keys_b64 | length >= 3)" /s/vault-keys.json' > /dev/null 2>&1; }

start_vault "$run_id-data1"
run_init || fail "fresh init failed: $(tail -5 "$log")"
keys_usable || fail "fresh init left no usable keys file"
first_keys="$(keys_sum)"
echo "ok: fresh init writes the keys"

start_vault "$run_id-data1"
run_init || fail "unseal after restart failed: $(tail -5 "$log")"
[ "$(keys_sum)" = "$first_keys" ] || fail "keys changed on a normal restart"
echo "ok: restart unseals with the same keys"

start_vault "$run_id-data2"
if run_init; then fail "init over existing keys on empty storage was not refused"; fi
grep -q "Nothing was changed" "$log" || fail "refusal message missing: $(tail -5 "$log")"
[ "$(keys_sum)" = "$first_keys" ] || fail "keys file changed although init was refused"
echo "ok: empty storage with existing keys is refused, keys untouched"

run_init -e VAULT_ALLOW_REINIT=true || fail "re-init with VAULT_ALLOW_REINIT=true failed: $(tail -5 "$log")"
[ "$(keys_sum)" != "$first_keys" ] || fail "keys not replaced by the allowed re-init"
keys_usable || fail "allowed re-init left no usable keys file"
echo "ok: VAULT_ALLOW_REINIT=true re-initializes (the restore path)"

in_secrets 'mv /s/vault-keys.json /s/vault-keys.json.aside' 
if run_init; then fail "initialized Vault without a keys file did not fail"; fi
grep -q "missing or not valid JSON" "$log" || fail "missing-keys message missing: $(tail -5 "$log")"
echo "ok: initialized Vault without a keys file fails loudly"

echo "PASS"
