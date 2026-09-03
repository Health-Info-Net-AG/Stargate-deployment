#!/bin/sh
# =============================================================================
# Stalwart Provision Script (Docker Compose)
# =============================================================================
# Idempotently provisions Stalwart for the HIN Gateway deployment:
#   1. Creates network listeners (SMTP, reinject, management HTTP)
#   2. Enables a Stdout tracer (docker stdout) + disables the built-in file tracer
#   3. Ensures the service domain exists
#   4. Sets SystemSettings (defaultHostname + defaultDomainId)
#   5. Creates the mtaconf service account
#
# Designed as a one-shot Docker Compose service (restart: "no").
# Safe to re-run: checks for existing objects before creating.
#
# Required env:
#   STALWART_RECOVERY_ADMIN   "admin:<password>" (recovery admin credentials)
#   MTACONF_SVC_PASSWORD      password for the mtaconf service account
# Optional env:
#   STALWART_URL              default http://stalwart:8080
#   STALWART_CLI_PATH         default /opt/stalwart-cli
#   STALWART_READY_RETRIES    readiness attempts, 3s apart (default 60)
#
# Internal: the mtaconf-svc admin account lives under a synthetic service
# domain (mtaconf.local). It exists only so mtaconf can authenticate to
# the Stalwart management API; it must NOT be a real mail-receiving
# domain, because Stalwart treats every registered Domain as
# accept-locally and would bounce production mail to that domain.
# Operators should never override this — that's why it's hardcoded here
# instead of being exposed in customer-config.
#
# The provisional SystemSettings.defaultHostname is also synthetic
# (mail.mtaconf.local). The real public mail hostname is set later via
# mtaconf when the operator submits the dashboard form (intent.hostname
# → SystemSettings.defaultHostname update).
# =============================================================================
set -eu
export HOME=/tmp

CLI="${STALWART_CLI_PATH:-/opt/stalwart-cli}"
URL="${STALWART_URL:-http://stalwart:8080}"
: "${STALWART_RECOVERY_ADMIN:?STALWART_RECOVERY_ADMIN (admin:password) is required}"
: "${MTACONF_SVC_PASSWORD:?MTACONF_SVC_PASSWORD is required}"
SVC="mtaconf-svc"
DOMAIN="mtaconf.local"
HOSTNAME="mail.${DOMAIN}"
RETRIES="${STALWART_READY_RETRIES:-60}"

AUSER="${STALWART_RECOVERY_ADMIN%%:*}"
APW="${STALWART_RECOVERY_ADMIN#*:}"
EMAIL="${SVC}@${DOMAIN}"

cli() { "$CLI" --url "$URL" --user "$AUSER" --password "$APW" "$@"; }
log() { echo "[provision] $*"; }

# =============================================================================
# 1. Wait for Stalwart management API
# =============================================================================
log "waiting for Stalwart at $URL"
i=0
until cli get SystemSettings >/dev/null 2>&1; do
  i=$((i + 1))
  if [ "$i" -ge "$RETRIES" ]; then
    log "ERROR: Stalwart not reachable after ${RETRIES} attempts"
    exit 1
  fi
  sleep 3
done
log "Stalwart reachable"

# =============================================================================
# 2. Create network listeners (idempotent)
# =============================================================================
create_listener() {
  local name="$1" bind="$2" protocol="$3" tls="${4:-false}"

  if cli query NetworkListener 2>/dev/null | grep -Fq "$name"; then
    log "listener '$name' already exists"
    return 0
  fi

  log "creating listener: $name (${protocol} on ${bind}, tls=${tls})"
  cli create NetworkListener \
    --field "name=${name}" \
    --field "bind={\"${bind}\": true}" \
    --field "protocol=${protocol}" \
    --field "useTls=${tls}"
}

# Content-filtering scope for the two SMTP listeners ('smtp' :25, 'reinject'
# :10026). Stalwart's milter `enable` field takes an Expression: yield "true"
# on a match, else "false". NOTE: 'match' is a Stalwart List, patched as an
# integer-keyed object ({"0": ...}) and NOT a JSON array -- an array is rejected
# with `invalidPatch: Invalid value for object property`.
SMTP_LISTENER_COND="listener == 'smtp' || listener == 'reinject'"
SMTP_LISTENERS="{\"match\":{\"0\":{\"if\":\"${SMTP_LISTENER_COND}\",\"then\":\"true\"}},\"else\":\"false\"}"

create_milter() {
  local name="$1" host="$2" port="$3"

  # MtaMilter has no 'name' property; its id is server-assigned. Identify an existing milter by its hostname (the only stable, operator-set key).
  if cli query MtaMilter 2>/dev/null | grep -Fq "$host"; then
    log "milter '$name' (${host}) already exists"
    return 0
  fi

  log "creating milter: $name (${host}:${port}, DATA stage, both SMTP listeners)"
  # stages is a Map<MtaStage> ({"<stage>": true}), not a list. The object id is assigned by Stalwart on create -- there is no settable name/id field.
  cli create MtaMilter \
    --field "hostname=${host}" \
    --field "port=${port}" \
    --field 'stages={"data":true}' \
    --field "enable=${SMTP_LISTENERS}" \
    --field "useTls=false" \
    --field "tempFailOnError=true"
}

# mailauth MTA hook (HTTP, DATA stage). Runs on BOTH SMTP listeners ('smtp'
# :25 and 'reinject' :10026) — same scope as the ClamAV milter — because it
# does different work on each leg: on ingress (:25) it verifies with the real
# client IP and stamps Authentication-Results; on egress (:10026, after
# mxengine) it DKIM-signs outbound and ARC-seals inbound over the final body.
# mailauth branches internally on context.server.port + domain role, so it must
# see both legs (scoping to smtp-only would drop all signing and sealing).
# NOTE: a MtaHook must be created WITHOUT an enable expression and then scoped via
# a follow-up `update` (the validated path); creating with enable inline fails
# validation. This differs from MtaMilter, which accepts enable at create time.
MAILAUTH_HOOK_URL="${MAILAUTH_HOOK_URL:-http://mailauth:8080/v1/hook}"
MAILAUTH_HOOK_SCOPE="{\"match\":{\"0\":{\"if\":\"listener == 'smtp' || listener == 'reinject'\",\"then\":\"true\"}},\"else\":\"false\"}"

create_mta_hook() {
  local url="$1" hid

  # Identify our hook by the mailauth host, not the full URL, so a path/version
  # change reconciles the existing hook in place instead of orphaning it.
  # Non-fatal throughout (like disable_throttles): this one-shot is gated by mtaconf via
  # service_completed_successfully, so a transient Stalwart-API failure here must warn, not abort.
  hid=$(cli query MtaHook 2>/dev/null | awk 'NR>1 && /mailauth:/ {print $1; exit}') || true
  if [ -z "$hid" ]; then
    log "creating MTA hook: ${url} (DATA stage, smtp + reinject listeners)"
    cli create MtaHook \
      --field "url=${url}" \
      --field 'stages={"data":true}' \
      --field "tempFailOnError=true" \
      || { log "WARN: could not create MTA hook for ${url}; skipping"; return 0; }
    hid=$(cli query MtaHook 2>/dev/null | awk 'NR>1 && /mailauth:/ {print $1; exit}') || true
  else
    log "MTA hook exists (id=${hid}); updating url to ${url}"
    cli update MtaHook "$hid" --field "url=${url}" \
      || { log "WARN: could not update MTA hook ${hid}; skipping"; return 0; }
  fi
  [ -n "$hid" ] || { log "WARN: could not resolve MtaHook id for ${url}; skipping"; return 0; }

  log "scoping mailauth hook ${hid} to smtp + reinject listeners"
  cli update MtaHook "$hid" --json "{\"enable\":${MAILAUTH_HOOK_SCOPE}}" \
    || log "WARN: could not scope MTA hook ${hid}"
}

# SMTP inbound (port 25) - receives external mail
create_listener "smtp" "0.0.0.0:25" "smtp" "false"

# Reinject (port 10026) - mxengine sends processed mail back here
create_listener "reinject" "0.0.0.0:10026" "smtp" "false"

# Management HTTP (port 8080) - already provided by recovery mode, but ensure
# it persists if recovery mode is ever disabled
create_listener "mgmt" "0.0.0.0:8080" "http" "false"

# =============================================================================
# 2b. Logging tracers: Stdout ON, built-in file tracer OFF
# =============================================================================
# v0.16 stores tracer config in the settings backend. A fresh backend is seeded
# with exactly one built-in tracer of `@type=Log` (a rotating FILE tracer) -- not
# a Stdout one -- which is why `docker logs stalwart` is silent on a fresh install
# even though the server is healthy, and why the box logs "Failed to create log
# file /var/log/stalwart/stalwart.log.<date>: No such file or directory": that Log
# tracer's default path is /var/log/stalwart, a directory the image doesn't ship.
#
# Fix, in two steps below:
#   1. ensure a Stdout tracer exists  -> logs go to docker's json-file (rotated) and
#      on to Loki via alloy. Stalwart names the Stdout/Console variant `Stdout`
#      (Console is the display label).
#   2. disable every built-in Log (file) tracer -> once Stdout carries the logs the
#      file tracer is pure redundancy, so we turn it off rather than mount a log dir
#      just to feed it. No file writes => the "No such file or directory" WARN stops.
if ! cli query Tracer 2>/dev/null | grep -Fq "Stdout"; then
  log "creating stdout tracer"
  cli create Tracer \
    --field "@type=Stdout" \
    --field "enable=true" \
    --field "level=info" \
    --field "ansi=false" \
    --field "multiline=false" \
    --field "buffered=false" \
    --field "lossy=false"
fi

# Disable the built-in Log (file) tracer(s), keeping the Stdout tracer above. Query id AND @type
# together with --fields: exactly like the throttle block below (see disable_throttles), that
# yields one compact object per row ({"@type":"...","id":"..."}). A bare `query Tracer --json` is
# NOT guaranteed one-per-line -- if it pretty-printed, @type and id would land on different lines,
# the per-row match/sed would find no id, and the loop would silently no-op (leaving the Log tracer
# enabled and /var/log/stalwart failing, with no trace). Fed via a here-doc rather than a pipe so
# $disabled survives into the count log. Reconciled every run (a fresh DB re-seeds the Log tracer)
# and non-fatal like the throttle/spam reconciliation below -- a failure must not abort this
# one-shot (mtaconf gates on it). The trailing count makes a no-op distinguishable from success.
disabled=0
tracers=$(cli query Tracer --fields id,@type --json 2>/dev/null) || true
while IFS= read -r row; do
  case "$row" in
    *'"@type":"Log"'*)
      tid=$(printf '%s' "$row" | sed -n 's/.*"id":"\([^"]*\)".*/\1/p')
      [ -n "$tid" ] || continue
      log "disabling built-in Log (file) tracer ${tid} (redundant with Stdout; wrote /var/log/stalwart)"
      if cli update Tracer "$tid" --json '{"enable":false}'; then
        disabled=$((disabled + 1))
      else
        log "WARNING: failed to disable Log tracer ${tid}; it may keep trying to write /var/log/stalwart"
      fi
      ;;
  esac
done <<EOF
$tracers
EOF
log "built-in Log (file) tracers disabled: ${disabled}"

# =============================================================================
# 2c. Content filtering: anti-virus (ClamAV milter)
# =============================================================================
# Anti-virus: ClamAV rejects infected mail at SMTP (OnInfected Reject in clamav-milter.conf); tempFailOnError defers mail if ClamAV is down instead of passing it unscanned (fail-closed).
create_milter "clamav" "${CLAMAV_MILTER_HOST:-clamav}" "${CLAMAV_MILTER_PORT:-7357}"

# mailauth owns inbound email authentication, so turn off Stalwart's own
# verification entirely (SPF/DKIM/DMARC/ARC + Reverse-IP). Otherwise Stalwart
# stamps its own Authentication-Results (e.g. iprev=pass) under the same
# authserv-id as mailauth, colliding with the header mailauth carries forward.
# Each field is an Expression; an empty match + else "disable" clears it.
log "disabling Stalwart inbound SPF/DKIM/DMARC/ARC/IPRev verification (mailauth owns these)"
cli update SenderAuth singleton --json '{"dkimVerify":{"match":{},"else":"disable"},"arcVerify":{"match":{},"else":"disable"},"spfEhloVerify":{"match":{},"else":"disable"},"spfFromVerify":{"match":{},"else":"disable"},"dmarcVerify":{"match":{},"else":"disable"},"reverseIpVerify":{"match":{},"else":"disable"}}'

# Anti-spam: disabled. Stalwart's built-in spam filter is explicitly turned off
# here (rather than left unconfigured) so that re-running provision reconciles a
# previously-enabled install back to disabled: no X-Spam-* tagging and no spam
# scan at the DATA stage.
log "disabling built-in spam filter"
cli update SpamSettings singleton --field "enable=false"
#cli update MtaStageData singleton --field "enableSpamFilter=false"

# =============================================================================
# 2d. Rate limiting: DISABLED (unlimited inbound + outbound)
# =============================================================================
# This deployment runs with NO SMTP rate limiting in either direction. There is
# no "unlimited" rate VALUE (the `rate` field is required and `count` is bounded
# 1..1000000), so "unlimited" means every throttle is switched off via its
# `enable` boolean. We disable rather than delete so the change is reversible and
# idempotent (a re-run re-asserts disabled; built-ins reappear on a fresh DB).
#
# We disable ALL throttles of each type, not just our own -- Stalwart ships
# built-in scoped defaults (e.g. "Sender IP throttle" 5/s per remote IP,
# "Sender address to recipient throttle" 25/h per pair). Leaving those enabled
# would NOT be unlimited, so they get disabled too.
#
# `query --fields id --json` emits one JSON object per row ({"id":"..."}); we
# extract every id and patch each with {"enable":false}.
#
# A failure here is non-fatal: mtaconf gates on this one-shot completing
# (docker-compose: service_completed_successfully), so an aborted `cli update`
# under `set -eu` would block the whole mail stack from starting. A throttle that
# fails to disable just keeps limiting -- the WARNING surfaces in
# `docker logs stargate-stalwart-provision`.
disable_throttles() {
  local type="$1"
  local ids id
  ids=$(cli query "$type" --fields id --json 2>/dev/null \
        | sed -n 's/.*"id":"\([^"]*\)".*/\1/p') || true
  if [ -z "$ids" ]; then
    log "no ${type} present; nothing to disable"
    return 0
  fi
  for id in $ids; do
    log "disabling ${type} ${id} (unlimited)"
    cli update "$type" "$id" --json '{"enable":false}' \
      || log "WARNING: failed to disable ${type} ${id}; it may still rate-limit"
  done
}

disable_throttles MtaInboundThrottle
disable_throttles MtaOutboundThrottle

# Email authentication (mailauth MTA hook): SPF/DKIM/DMARC/ARC verify + seal inbound, DKIM-sign on
# the reinject/egress leg. Fail-closed (tempFailOnError=true). Registered LAST + non-fatally so a
# hook failure can't abort this one-shot (mtaconf gates on it) or leave the spam filter + throttles
# reconciled-off while the box is otherwise half-provisioned.
create_mta_hook "$MAILAUTH_HOOK_URL"

# =============================================================================
# 2e. Data retention: hourly cleanup
# =============================================================================
# Hourly cleanup of the data store and the (reference-counted) blob store.
# Offset so the two purges don't compete for I/O. blob @ :05, data @ :15.
log "setting DataRetention cleanup schedules (blob hourly @ :05, data hourly @ :15)"
cli update DataRetention singleton \
  --field 'blobCleanupSchedule={"@type":"Hourly","minute":5}' \
  --field 'dataCleanupSchedule={"@type":"Hourly","minute":15}'

# =============================================================================
# 3. Ensure the domain exists
# =============================================================================
DID=$(cli query domain 2>/dev/null | awk -v d="$DOMAIN" 'NR>1 && index($0, d) {print $1; exit}') || true
if [ -z "$DID" ]; then
  log "creating domain: ${DOMAIN}"
  cli create domain \
    --field "name=${DOMAIN}" \
    --field 'aliases={}' \
    --field 'certificateManagement={"@type":"Manual"}' \
    --field 'dkimManagement={"@type":"Manual"}' \
    --field 'dnsManagement={"@type":"Manual"}' \
    --field 'subAddressing={"@type":"Enabled"}' \
    --field "isEnabled=true"
  DID=$(cli query domain 2>/dev/null | awk -v d="$DOMAIN" 'NR>1 && index($0, d) {print $1; exit}') || true
fi
[ -n "$DID" ] || { log "ERROR: could not resolve domain id for ${DOMAIN}"; exit 1; }
log "domain ${DOMAIN} id=${DID}"

# =============================================================================
# 4. Set SystemSettings (hostname + default domain)
# =============================================================================
# v0.16's SystemSettings requires both `defaultHostname` and `defaultDomainId`
# on every update — the validator runs against the full post-patch state, so
# subsequent partial updates (e.g. from mtaconf updating only the hostname)
# fail with "defaultDomainId: required" unless we seed both fields here.
log "setting SystemSettings: defaultHostname=${HOSTNAME}, defaultDomainId=${DID}"
cli update SystemSettings singleton \
  --field "defaultHostname=${HOSTNAME}" \
  --field "defaultDomainId=${DID}"

# =============================================================================
# 5. Ensure mtaconf service account exists
# =============================================================================
CRED='{"0":{"@type":"Password","secret":"'"${MTACONF_SVC_PASSWORD}"'"}}'
ROLES='{"@type":"Admin"}'

if cli query account 2>/dev/null | grep -Fq "$EMAIL"; then
  AID=$(cli query account 2>/dev/null | awk -v e="$EMAIL" 'NR>1 && index($0, e) {print $1; exit}') || true
  log "account ${EMAIL} exists (id=${AID}); reconciling password + role"
  cli update account "$AID" \
    --field "credentials=${CRED}" \
    --field "roles=${ROLES}"
else
  log "creating account: ${EMAIL} (role Admin)"
  cli create account/user \
    --field "name=${SVC}" \
    --field "domainId=${DID}" \
    --field "credentials=${CRED}" \
    --field "roles=${ROLES}" \
    --field 'permissions={"@type":"Inherit"}'
fi

# =============================================================================
# 6. Reload settings so listeners take effect without restart
# =============================================================================
log "triggering ReloadSettings"
cli create action/ReloadSettings 2>/dev/null || log "ReloadSettings trigger skipped"

log "done: Stalwart provisioned, mtaconf service account ready (login: ${EMAIL})"
