#!/bin/bash
# shellcheck disable=SC2034

KEYCLOAK_SYNC_CLIENT_ID="stargate-sync"
KEYCLOAK_SYNC_BOOTSTRAP_DIR="$SECRETS_DIR/keycloak-sync"
KEYCLOAK_SYNC_BOOTSTRAP_FILE="$KEYCLOAK_SYNC_BOOTSTRAP_DIR/admin"

keycloak_db_user() {
  local user
  user=$(read_env_var POSTGRES_USER "$ENV_FILE")
  printf '%s' "${user:-postgres}"
}

wait_for_keycloak_db() {
  local user attempt
  user=$(keycloak_db_user)
  for attempt in $(seq 1 30); do
    if docker exec stargate-postgres pg_isready -q -U "$user" -h 127.0.0.1 > /dev/null 2>&1; then
      return 0
    fi
    sleep 2
  done
  return 1
}

keycloak_db_query() {
  docker exec -i stargate-postgres psql -X -q -t -A -F ' ' -v ON_ERROR_STOP=1 \
    -U "$(keycloak_db_user)" -d keycloak
}

keycloak_sync_client_state() {
  local schema
  schema=$(keycloak_db_query <<< "SELECT to_regclass('public.realm') IS NOT NULL;") || return 1
  if [ "$schema" != "t" ]; then
    echo "0 - 0"
    return 0
  fi
  keycloak_db_query <<SQL
SELECT
  (SELECT count(*) FROM realm WHERE name = 'stargate'),
  coalesce((SELECT encode(sha256(convert_to(c.secret, 'UTF8')), 'hex')
              FROM client c JOIN realm r ON r.id = c.realm_id
             WHERE r.name = 'stargate' AND c.client_id = '$KEYCLOAK_SYNC_CLIENT_ID'
               AND c.enabled AND c.service_accounts_enabled), '-'),
  (SELECT count(*)
     FROM client c
     JOIN realm r ON r.id = c.realm_id
     JOIN user_entity u ON u.service_account_client_link = c.id
     JOIN user_role_mapping m ON m.user_id = u.id
     JOIN keycloak_role kr ON kr.id = m.role_id
     JOIN client rm ON rm.id = kr.client
    WHERE r.name = 'stargate' AND c.client_id = '$KEYCLOAK_SYNC_CLIENT_ID'
      AND rm.realm_id = r.id AND rm.client_id = 'realm-management'
      AND kr.name = 'manage-clients');
SQL
}

keycloak_sync_client_ready() {
  local secret state realm hash roles
  secret=$(read_env_var KEYCLOAK_SYNC_CLIENT_SECRET "$ENV_FILE")
  wait_for_keycloak_db || return 2
  state=$(keycloak_sync_client_state) || return 2
  read -r realm hash roles <<< "$state"
  [ "$realm" = "1" ] || return 0
  [ "$roles" = "1" ] && [ "$hash" = "$(printf '%s' "$secret" | sha256sum | cut -d' ' -f1)" ]
}

ensure_keycloak_sync_client() {
  local secret rc temp_id temp_secret output

  mkdir -p "$KEYCLOAK_SYNC_BOOTSTRAP_DIR"
  chmod 700 "$KEYCLOAK_SYNC_BOOTSTRAP_DIR"
  rm -f "$KEYCLOAK_SYNC_BOOTSTRAP_FILE"

  secret=$(read_env_var KEYCLOAK_SYNC_CLIENT_SECRET "$ENV_FILE")
  if [ -z "$secret" ]; then
    echo "WARNING: KEYCLOAK_SYNC_CLIENT_SECRET is not set in $ENV_FILE." >&2
    return 1
  fi

  if [ "$(docker inspect -f '{{.State.Running}}' stargate-keycloak 2> /dev/null)" = "true" ]; then
    echo "WARNING: Keycloak is running; the $KEYCLOAK_SYNC_CLIENT_ID check needs it stopped." >&2
    return 1
  fi

  rc=0
  keycloak_sync_client_ready || rc=$?
  case $rc in
    0) return 0 ;;
    2)
      echo "WARNING: could not read the Keycloak database." >&2
      return 1
      ;;
  esac

  temp_id="stargate-bootstrap-$(openssl rand -hex 4)"
  temp_secret=$(openssl rand -hex 24)
  echo "Keycloak client $KEYCLOAK_SYNC_CLIENT_ID is missing or out of date; creating the temporary admin $temp_id..."
  if ! output=$(STARGATE_TEMP_ADMIN_SECRET="$temp_secret" compose run --rm --no-deps -T \
       -e STARGATE_TEMP_ADMIN_SECRET --entrypoint /opt/keycloak/bin/kc.sh keycloak-sync \
       bootstrap-admin service --client-id="$temp_id" \
       --client-secret:env=STARGATE_TEMP_ADMIN_SECRET --no-prompt 2>&1); then
    printf '%s\n' "$output" >&2
    return 1
  fi

  (umask 077 && printf '%s\n%s\n' "$temp_id" "$temp_secret" > "$KEYCLOAK_SYNC_BOOTSTRAP_FILE")
  echo "  keycloak-sync will provision $KEYCLOAK_SYNC_CLIENT_ID and delete $temp_id."
}
