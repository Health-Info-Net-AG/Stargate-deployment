#!/bin/bash
set -euo pipefail

KC_URL="http://keycloak:8080"
REALM="stargate"
SYNC_CLIENT="stargate-sync"
TEMP_PREFIX="stargate-bootstrap"
BOOTSTRAP_FILE="/bootstrap/admin"
SYNC_SECRET="${KEYCLOAK_SYNC_CLIENT_SECRET:-}"
unset KEYCLOAK_SYNC_CLIENT_SECRET
KCADM_DIR="$(mktemp -d)"
KCADM_CONFIG="$KCADM_DIR/kcadm.config"
TEMP_ID=""

cleanup() {
  if [ -n "$TEMP_ID" ]; then
    delete_temp_admins || echo "WARNING: could not delete the temporary admin $TEMP_ID" >&2
  fi
  rm -rf "$KCADM_DIR"
}
trap cleanup EXIT

kcadm() { /opt/keycloak/bin/kcadm.sh "$@" --config "$KCADM_CONFIG"; }

login() {
  KC_CLI_CLIENT_SECRET="$3" /opt/keycloak/bin/kcadm.sh config credentials --config "$KCADM_CONFIG" \
    --server "$KC_URL" --realm "$1" --client "$2" > /dev/null 2>&1
}

json_string() {
  local s=$1
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  printf '"%s"' "$s"
}

client_uuid() {
  kcadm get clients -r "$1" -q clientId="$2" --fields id --format csv --noquotes
}

delete_temp_admins() {
  local uuid name
  while IFS=, read -r uuid name; do
    case "$name" in
      "$TEMP_ID") ;;
      "$TEMP_PREFIX"*)
        if kcadm delete "clients/$uuid" -r master > /dev/null; then
          echo "==> removed the leftover temporary admin $name"
        else
          echo "WARNING: could not delete the leftover temporary admin $name" >&2
        fi
        ;;
    esac
  done < <(kcadm get clients -r master --fields id,clientId --format csv --noquotes)
  kcadm delete "clients/$(client_uuid master "$TEMP_ID")" -r master > /dev/null
  echo "==> removed the temporary admin $TEMP_ID"
  TEMP_ID=""
}

provision_sync_client() {
  local temp_id temp_secret uuid secret_json
  { read -r temp_id && read -r temp_secret; } < "$BOOTSTRAP_FILE" || true
  rm -f "$BOOTSTRAP_FILE"
  if [ -z "${temp_id:-}" ] || [ -z "${temp_secret:-}" ]; then
    echo "ERROR: $BOOTSTRAP_FILE is incomplete" >&2
    return 1
  fi
  if ! login master "$temp_id" "$temp_secret"; then
    echo "ERROR: the temporary admin $temp_id could not log in" >&2
    return 1
  fi
  TEMP_ID="$temp_id"
  echo "==> provisioning $SYNC_CLIENT through the temporary admin $TEMP_ID"

  secret_json=$(json_string "$SYNC_SECRET")
  uuid=$(client_uuid "$REALM" "$SYNC_CLIENT")
  if [ -z "$uuid" ]; then
    kcadm create clients -r "$REALM" -f - > /dev/null <<EOF
{"clientId":"$SYNC_CLIENT","enabled":true,"protocol":"openid-connect","publicClient":false,"clientAuthenticatorType":"client-secret","secret":$secret_json,"serviceAccountsEnabled":true,"standardFlowEnabled":false,"implicitFlowEnabled":false,"directAccessGrantsEnabled":false,"bearerOnly":false}
EOF
    echo "==> created $SYNC_CLIENT"
  else
    kcadm update "clients/$uuid" -r "$REALM" --merge -f - > /dev/null <<< "{\"secret\":$secret_json,\"enabled\":true,\"serviceAccountsEnabled\":true}"
    echo "==> $SYNC_CLIENT exists: set the configured secret"
  fi
  kcadm add-roles -r "$REALM" --uusername "service-account-$SYNC_CLIENT" \
    --cclientid realm-management --rolename manage-clients

  delete_temp_admins
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

if [ -z "$SYNC_SECRET" ]; then
  rm -f "$BOOTSTRAP_FILE"
  echo "WARNING: KEYCLOAK_SYNC_CLIENT_SECRET is empty: Keycloak clients not synced" >&2
  exit 0
fi

if [ -e "$BOOTSTRAP_FILE" ]; then
  provision_sync_client
fi

if ! login "$REALM" "$SYNC_CLIENT" "$SYNC_SECRET"; then
  echo "ERROR: $SYNC_CLIENT cannot log in to Keycloak: clients not synced" >&2
  exit 1
fi

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
