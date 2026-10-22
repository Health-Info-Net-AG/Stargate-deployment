#!/bin/bash
set -euo pipefail

KC_URL="http://keycloak:8080"
REALM="stargate"
SYNC_CLIENT="stargate-sync"
TEMP_PREFIX="stargate-bootstrap"
SECRET_FILE="/secrets/keycloak-sync-client-secret"
KCADM_CONFIG="$(mktemp -d)/kcadm.config"

kcadm() { /opt/keycloak/bin/kcadm.sh "$@" --config "$KCADM_CONFIG"; }

random_secret() { od -An -tx1 -N24 /dev/urandom | tr -d ' \n'; }

client_uuid() {
  kcadm get clients -r "$1" -q clientId="$2" --fields id --format csv --noquotes
}

login_sync() {
  [ -s "$SECRET_FILE" ] || return 1
  kcadm config credentials --server "$KC_URL" --realm "$REALM" \
    --client "$SYNC_CLIENT" --secret "$(cat "$SECRET_FILE")" > /dev/null 2>&1
}

delete_temp_admins() {
  local current=$1 uuid name
  while IFS=, read -r uuid name; do
    case "$name" in
      "$current") ;;
      "$TEMP_PREFIX"*)
        kcadm delete "clients/$uuid" -r master > /dev/null \
          || echo "WARNING: could not delete the leftover temporary admin $name" >&2
        ;;
    esac
  done < <(kcadm get clients -r master --fields id,clientId --format csv --noquotes)
  kcadm delete "clients/$(client_uuid master "$current")" -r master > /dev/null
}

provision_sync_client() {
  local suffix temp_id temp_secret new_secret uuid
  suffix=$(random_secret)
  temp_id="$TEMP_PREFIX-${suffix:0:8}"
  temp_secret=$(random_secret)

  echo "==> $SYNC_CLIENT cannot log in: provisioning it through a temporary admin ($temp_id)"
  TEMP_ADMIN_SECRET="$temp_secret" /opt/keycloak/bin/kc.sh bootstrap-admin service \
    --client-id="$temp_id" --client-secret:env=TEMP_ADMIN_SECRET --no-prompt > /tmp/bootstrap-admin.log 2>&1 || true
  if ! kcadm config credentials --server "$KC_URL" --realm master \
       --client "$temp_id" --secret "$temp_secret" > /dev/null 2>&1; then
    cat /tmp/bootstrap-admin.log >&2
    echo "ERROR: the temporary admin $temp_id could not log in" >&2
    exit 1
  fi

  new_secret=$(random_secret)
  uuid=$(client_uuid "$REALM" "$SYNC_CLIENT")
  if [ -z "$uuid" ]; then
    kcadm create clients -r "$REALM" -s clientId="$SYNC_CLIENT" -s enabled=true \
      -s publicClient=false -s serviceAccountsEnabled=true -s standardFlowEnabled=false \
      -s directAccessGrantsEnabled=false -s clientAuthenticatorType=client-secret \
      -s secret="$new_secret" -i > /dev/null
    echo "==> created $SYNC_CLIENT"
  else
    kcadm update "clients/$uuid" -r "$REALM" -s secret="$new_secret" > /dev/null
    echo "==> $SYNC_CLIENT exists: set a new secret"
  fi
  kcadm add-roles -r "$REALM" --uusername "service-account-$SYNC_CLIENT" \
    --cclientid realm-management --rolename manage-clients

  (umask 077 && printf '%s' "$new_secret" > "$SECRET_FILE.tmp")
  mv "$SECRET_FILE.tmp" "$SECRET_FILE"

  delete_temp_admins "$temp_id"
  echo "==> removed the temporary admin"

  login_sync || { echo "ERROR: $SYNC_CLIENT cannot log in after provisioning" >&2; exit 1; }
}

sync_client() {
  local name=$1 redirect=$2 origin=$3 uuid current want
  uuid=$(client_uuid "$REALM" "$name")
  if [ -z "$uuid" ]; then
    echo "WARNING: client $name not found in realm $REALM, skipped" >&2
    return 0
  fi
  want="{\"redirectUris\":[\"$redirect\"],\"webOrigins\":[\"$origin\"]}"
  current=$(kcadm get "clients/$uuid" -r "$REALM" --fields redirectUris,webOrigins 2> /dev/null | tr -d ' \n')
  if [ "$current" = "$want" ]; then
    echo "==> $name: up to date ($origin)"
    return 0
  fi
  kcadm update "clients/$uuid" -r "$REALM" \
    -s "redirectUris=[\"$redirect\"]" -s "webOrigins=[\"$origin\"]" > /dev/null
  echo "==> $name: was $current, now $want"
}

login_sync || provision_sync_client

dashboard_url="${DASHBOARD_PUBLIC_URL:-}"
dashboard_url="${dashboard_url%/}"
dozzle_url="${DOZZLE_PUBLIC_URL:-}"
dozzle_url="${dozzle_url%/}"

if [ -n "$dashboard_url" ]; then
  sync_client dashboard "$dashboard_url/*" "$dashboard_url"
  sync_client app "$dashboard_url/*" "$dashboard_url"
else
  echo "WARNING: DASHBOARD_PUBLIC_URL is empty: dashboard and app clients not synced" >&2
fi

if [ -n "$dozzle_url" ]; then
  sync_client dozzle "$dozzle_url/oauth2/callback" "$dozzle_url"
else
  echo "WARNING: DOZZLE_PUBLIC_URL is empty: dozzle client not synced" >&2
fi
