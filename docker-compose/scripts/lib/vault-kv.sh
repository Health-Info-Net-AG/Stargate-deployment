#!/bin/bash

VAULT_KV_ADDR="http://127.0.0.1:8200"

vault_kv_backup_path() {
  local mount=$1 prefix=$2 dest=$3 keys key data out
  local -a list

  # `kv list` exits 2 both for an empty path and for a failure (refused,
  # sealed, unreachable), so stderr is what separates them: with -format=json
  # an empty path writes nothing there.
  : > "$VAULT_ERR"
  keys=$(docker exec -e VAULT_TOKEN stargate-vault \
    vault kv list -address="$VAULT_KV_ADDR" -format=json "$mount/$prefix" 2>"$VAULT_ERR") || keys=""

  if [ -s "$VAULT_ERR" ]; then
    echo "    ✗ ERROR: could not list $mount/$prefix: $(grep -m1 -E '^\* ' "$VAULT_ERR" || head -1 "$VAULT_ERR")"
    VAULT_BACKUP_INCOMPLETE=true
    return 0
  fi

  if [ "$keys" = "[]" ] || [ -z "$keys" ]; then
    [ -n "$prefix" ] || echo "    - No secrets found"
    return 0
  fi

  mapfile -t list < <(jq -r '.[]' <<< "$keys" 2>/dev/null)
  for key in "${list[@]}"; do
    case "$key" in
      ""|.|..|./|../)
        echo "    ✗ ERROR: unexpected key name '$key' under $mount/$prefix, skipped"
        VAULT_BACKUP_INCOMPLETE=true
        continue
        ;;
      */)
        vault_kv_backup_path "$mount" "$prefix$key" "$dest"
        continue
        ;;
    esac

    : > "$VAULT_ERR"
    data=$(docker exec -e VAULT_TOKEN stargate-vault \
      vault kv get -address="$VAULT_KV_ADDR" -format=json "$mount/$prefix$key" 2>"$VAULT_ERR") || data=""

    if grep -qiE 'permission denied|403' "$VAULT_ERR"; then
      echo "    ✗ ERROR: permission denied reading $mount/$prefix$key"
      VAULT_BACKUP_INCOMPLETE=true
      continue
    fi

    if [ -n "$data" ] && [ "$data" != "{}" ]; then
      out="$dest/$prefix$key.json"
      mkdir -p "$(dirname "$out")"
      echo "$data" > "$out"
      echo "    ✓ $prefix$key"
      ((VAULT_SECRETS_COUNT++)) || true
    elif [ -s "$VAULT_ERR" ]; then
      echo "    ✗ ERROR: could not read $mount/$prefix$key"
      VAULT_BACKUP_INCOMPLETE=true
    else
      # Listed but no current version: a soft-deleted key, not a failure.
      echo "    - $prefix$key (no current version)"
    fi
  done
}

vault_kv_restore_mount_dir() {
  local mount_dir=${1%/} mount_name rel key data secret_file
  mount_name=$(basename "$mount_dir")

  while IFS= read -r -d '' secret_file <&3; do
    rel=${secret_file#"$mount_dir"/}
    key=${rel%.json}
    data=$(jq -r '.data.data // empty' "$secret_file" 2>/dev/null)
    [ -n "$data" ] || continue
    if echo "$data" | docker exec -i -e VAULT_TOKEN stargate-vault \
      vault kv put -address="$VAULT_KV_ADDR" "$mount_name/$key" - > /dev/null 2>&1; then
      echo "      ✓ $key"
      ((RESTORED_SECRETS++)) || true
    else
      echo "      ✗ Failed to restore $key"
    fi
  done 3< <(find "$mount_dir" -type f -name '*.json' -print0 | sort -z)
}
