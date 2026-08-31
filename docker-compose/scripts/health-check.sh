#!/bin/bash
# ==============================================================================
# Stargate Health Check
# ==============================================================================
# Performs a comprehensive health check of all Stargate services.
# Exit code: 0 = all healthy, 1 = one or more issues found.

# paths.sh is the single source of truth for writable-state locations under
# /var/data; sourced (not hardcoded) so the STARGATE_DATA_DIR test override works here too.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
. "$SCRIPT_DIR/lib/paths.sh"

PASS=0
WARN=0
FAIL=0
VERBOSE=false

# Parse flags
for arg in "$@"; do
  case "$arg" in
    -v|--verbose) VERBOSE=true ;;
  esac
done

pass() { echo "  [OK]   $1"; PASS=$((PASS + 1)); }
warn() { echo "  [WARN] $1"; WARN=$((WARN + 1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL + 1)); }

echo "============================================"
echo "  Stargate Health Check"
echo "============================================"
echo ""

# ------------------------------------------------------------------
# 1. Container status
# ------------------------------------------------------------------
echo "--- Containers ---"

EXPECTED_RUNNING=(
  stargate-postgres
  stargate-vault
  stargate-seaweedfs
  stargate-smimekeys-client
  stargate-policy
  stargate-irisagent
  stargate-mxengine
  stargate-idagent
  stargate-mailauth
  stargate-stalwart
  stargate-mtaconf
  stargate-alloy
  stargate-node-exporter
)

for cname in "${EXPECTED_RUNNING[@]}"; do
  status=$(docker inspect -f '{{.State.Status}}' "$cname" 2>/dev/null)
  if [ "$status" = "running" ]; then
    health=$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$cname" 2>/dev/null)
    if [ "$health" = "unhealthy" ]; then
      fail "$cname running but UNHEALTHY"
    else
      pass "$cname"
    fi
  elif [ -z "$status" ]; then
    fail "$cname not found"
  else
    fail "$cname status: $status"
  fi
done

# policy-sync is optional (may not be running if not configured)
ps_status=$(docker inspect -f '{{.State.Status}}' stargate-policy-sync 2>/dev/null)
if [ "$ps_status" = "running" ]; then
  pass "stargate-policy-sync"
elif [ -n "$ps_status" ]; then
  warn "stargate-policy-sync status: $ps_status (optional service)"
fi

# watcher is optional (compose profile keri-watcher; only run when this
# deployment verifies external anchors)
watcher_status=$(docker inspect -f '{{.State.Status}}' stargate-watcher 2>/dev/null)
if [ "$watcher_status" = "running" ]; then
  pass "stargate-watcher"
elif [ -n "$watcher_status" ]; then
  warn "stargate-watcher status: $watcher_status (optional service)"
fi

echo ""

# ------------------------------------------------------------------
# 2. Liveness endpoints
# ------------------------------------------------------------------
echo "--- Liveness ---"

declare -A LIVENESS_ENDPOINTS=(
  [smimekeys-client]=8081
  [policy]=8082
  [irisagent]=8083
  [mxengine]=8084
  [idagent]=8085
  [mailauth]=8086
)

for svc in "${!LIVENESS_ENDPOINTS[@]}"; do
  port=${LIVENESS_ENDPOINTS[$svc]}
  resp=$(curl -sf --max-time 5 "http://localhost:${port}/liveness" 2>/dev/null)
  if [ $? -eq 0 ]; then
    pass "$svc :${port}/liveness"
    if $VERBOSE && [ -n "$resp" ]; then
      echo "         $resp"
    fi
  else
    fail "$svc :${port}/liveness"
  fi
done

echo ""

# ------------------------------------------------------------------
# 3. Vault
# ------------------------------------------------------------------
echo "--- Vault ---"

vault_status=$(docker exec stargate-vault vault status -format=json 2>/dev/null)
if [ $? -eq 0 ] || [ -n "$vault_status" ]; then
  sealed=$(echo "$vault_status" | grep '"sealed"' | grep -o 'true\|false')
  if [ "$sealed" = "false" ]; then
    pass "Vault unsealed"
  else
    fail "Vault is SEALED — run ./scripts/start.sh"
  fi
else
  fail "Vault unreachable"
fi

echo ""

# ------------------------------------------------------------------
# 4. PostgreSQL
# ------------------------------------------------------------------
echo "--- PostgreSQL ---"

if docker exec stargate-postgres pg_isready -U postgres >/dev/null 2>&1; then
  pass "PostgreSQL accepting connections"
else
  fail "PostgreSQL not ready"
fi

for db in smimekeys_client policy irisagent mxengine idagent idagent_keri; do
  count=$(docker exec stargate-postgres psql -U postgres -d "$db" -tAc "SELECT 1" 2>/dev/null)
  if [ "$count" = "1" ]; then
    pass "Database: $db"
  else
    fail "Database: $db (cannot connect)"
  fi
done

echo ""

# ------------------------------------------------------------------
# 5. SeaweedFS (S3)
# ------------------------------------------------------------------
echo "--- SeaweedFS ---"

if curl -sf --max-time 5 "http://localhost:8333/status" >/dev/null 2>&1; then
  pass "SeaweedFS S3 live"
else
  fail "SeaweedFS health check failed"
fi

echo ""

# ------------------------------------------------------------------
# 6. WireGuard tunnel
# ------------------------------------------------------------------
echo "--- WireGuard ---"

wg_output=$(docker exec stargate-irisagent wg show 2>/dev/null)
if [ $? -eq 0 ] && [ -n "$wg_output" ]; then
  peer_count=$(echo "$wg_output" | grep -c "^peer:")
  if [ "$peer_count" -gt 0 ]; then
    pass "WireGuard interface up ($peer_count peer(s))"
    # Check latest handshake (indicates active tunnel)
    handshake=$(echo "$wg_output" | grep "latest handshake" | head -1)
    if [ -n "$handshake" ]; then
      pass "Tunnel active — $handshake"
    else
      warn "No recent handshake (tunnel may not have exchanged data yet)"
    fi
  else
    warn "WireGuard interface up but no peers configured"
  fi
  if $VERBOSE; then
    echo "$wg_output" | sed 's/^/         /'
  fi
else
  warn "WireGuard interface not available (irisagent may still be initializing)"
fi

echo ""

# ------------------------------------------------------------------
# 7. Stalwart MTA
# ------------------------------------------------------------------
echo "--- Stalwart MTA ---"

# Check management API reachable (matches the container's own healthcheck path)
if docker exec stargate-stalwart curl -sf http://127.0.0.1:8080/healthz/live >/dev/null 2>&1; then
  pass "Stalwart management API reachable"
else
  fail "Stalwart management API unreachable"
fi

# Check the SMTP listeners. The stalwart image has no ss/netstat, so read
# /proc/net/tcp{,6} inside the container (always present) and look for a socket
# in LISTEN state (st=0A) on the port in hex. 25=0x0019, 10026=0x272A.
stalwart_listening() {  # $1 = decimal port
  local hexport
  hexport=$(printf ':%04X' "$1")
  docker exec stargate-stalwart sh -c 'cat /proc/net/tcp /proc/net/tcp6 2>/dev/null' \
    | awk '$4 == "0A" { print $2 }' | grep -qi "$hexport\$"
}

if stalwart_listening 25; then
  pass "Port 25 listening"
else
  fail "Port 25 not listening (provision may not have run yet)"
fi

if stalwart_listening 10026; then
  pass "Port 10026 (reinjection) listening"
else
  fail "Port 10026 (reinjection) not listening (provision may not have run yet)"
fi

echo ""

# ------------------------------------------------------------------
# 8. Metrics endpoints
# ------------------------------------------------------------------
echo "--- Metrics ---"

declare -A METRICS_ENDPOINTS=(
  [smimekeys-client]=2113
  [irisagent]=2114
  [policy]=2115
  [mxengine]=2116
  [node-exporter]=9100
)

for svc in "${!METRICS_ENDPOINTS[@]}"; do
  port=${METRICS_ENDPOINTS[$svc]}
  # Test curl directly, not `$?` after a pipeline: piping through `head` made
  # `$?` report head's status (always 0), so every endpoint reported OK even
  # when it was down.
  if curl -sf --max-time 5 "http://localhost:${port}/metrics" >/dev/null 2>&1; then
    pass "$svc :${port}/metrics"
  else
    fail "$svc :${port}/metrics"
  fi
done

echo ""

# ------------------------------------------------------------------
# 9. Disk & resources
# ------------------------------------------------------------------
echo "--- Resources ---"

# Docker disk usage (volumes)
volumes_size=$(docker system df --format '{{.Size}}' 2>/dev/null | tail -1)
if [ -n "$volumes_size" ]; then
  echo "  [INFO] Docker volumes size: $volumes_size"
fi

# Host disk usage. Check the WRITABLE filesystems, not "/": on a bootc
# appliance / is a read-only composefs mount that is 100% used by construction,
# so the old `df /` check reported FAIL on every healthy appliance and made the
# script's exit status useless. /var backs the ostree root and docker's image
# store; /var/data is the Data Disk -- a separate mount on an appliance, the
# same filesystem as /var on a plain Docker install (deduped by source below).
# df -P keeps each entry on one line; -h can wrap a long device name and shift
# the awk field.
seen_fs=""
for mnt in /var /var/data; do
  [ -d "$mnt" ] || continue
  read -r fs_src disk_pct <<<"$(df -P "$mnt" 2>/dev/null | awk 'NR==2{gsub(/%/,"",$5); print $1, $5}')"
  [ -n "$disk_pct" ] || continue
  case " $seen_fs " in *" $fs_src "*) continue ;; esac
  seen_fs="$seen_fs $fs_src"

  if [ "$disk_pct" -ge 90 ]; then
    fail "Disk $mnt ${disk_pct}% full"
  elif [ "$disk_pct" -ge 80 ]; then
    warn "Disk $mnt ${disk_pct}% full"
  else
    pass "Disk $mnt ${disk_pct}% used"
  fi
done

# Memory
mem_info=$(free -h 2>/dev/null | awk 'NR==2{printf "%s used / %s total (%s available)", $3, $2, $7}')
if [ -n "$mem_info" ]; then
  echo "  [INFO] Memory: $mem_info"
fi

echo ""

# ------------------------------------------------------------------
# 10. Time synchronisation
# ------------------------------------------------------------------
# Clock skew is a silent, high-blast-radius failure here: S/MIME and TLS chain
# validation, KERI event timestamps, DKIM signature windows and Keycloak token
# lifetimes all reject valid input once the clock drifts. Warn, never fail --
# an unreachable site NTP server must not make health-check exit non-zero.
echo "--- Time ---"

if ! command -v chronyc >/dev/null 2>&1; then
  echo "  [INFO] chronyc not installed - skipping time checks (not a bootc appliance?)"
else
  tracking=$(chronyc -c tracking 2>/dev/null || true)
  if [ -z "$tracking" ]; then
    warn "chronyd is not reachable - clock is unmanaged"
  else
    # chronyc -c tracking is a 14-field CSV:
    # 1 refid, 2 ref name, 3 stratum, 4 ref time, 5 system time offset, ... 14 leap status.
    refid=$(echo "$tracking" | cut -d, -f1)
    refname=$(echo "$tracking" | cut -d, -f2)
    stratum=$(echo "$tracking" | cut -d, -f3)
    offset=$(echo "$tracking" | cut -d, -f5)
    leap=$(echo "$tracking" | cut -d, -f14)

    # 00000000 = never synchronised; 7F7F0101 = the local reference clock, i.e. chronyd
    # is running but has no usable external source. Leap status alone is NOT sufficient:
    # it still reads "Normal" while disciplined only by the local clock.
    case "$refid" in
      00000000|7F7F0101)
        warn "clock not synchronised to an NTP source (refid $refid, leap $leap)"
        ;;
      *)
        # One verdict per clock. Anything past a second is well beyond NTP's working
        # range and means the source is reachable but wrong, or has only just come
        # back -- that is a warning, not a pass with a footnote.
        if awk -v o="$offset" 'BEGIN { exit !(o < -1.0 || o > 1.0) }' 2>/dev/null; then
          warn "clock offset from ${refname:-$refid} is ${offset}s - beyond NTP's working range"
        else
          pass "clock synchronised to ${refname:-$refid} (stratum $stratum, offset ${offset}s)"
        fi
        ;;
    esac

    src_count=$(chronyc -c sources 2>/dev/null | grep -c . || true)
    echo "  [INFO] NTP sources configured: ${src_count:-0}"
    # File existence alone does not mean chronyd reads it: on the manual-install
    # distros the docs support, /etc/chrony.conf has no sourcedir at all, so the file
    # would be reported as active while chronyd ignores it. Confirm the wiring, and
    # say so plainly when a site has written the file but nothing consumes it.
    if [ -f "$CHRONY_SOURCES_FILE" ]; then
      if grep -q "^sourcedir.*$CHRONY_DIR" /etc/chrony.conf 2>/dev/null; then
        echo "  [INFO] using site NTP override: $CHRONY_SOURCES_FILE"
      else
        warn "$CHRONY_SOURCES_FILE exists but no sourcedir in /etc/chrony.conf reads it - chronyd is ignoring it"
      fi
    fi

    # chrony shadows per FILENAME, so only ntp.sources replaces the shipped default.
    # Any other *.sources name is loaded IN ADDITION to it, which silently leaves
    # ntp.metas.ch active on a site that believes it removed it.
    stray=""
    for f in "$CHRONY_DIR"/*.sources; do
      [ -e "$f" ] || continue
      case "${f##*/}" in
        ntp.sources) ;;
        *) stray="$stray ${f##*/}" ;;
      esac
    done
    if [ -n "$stray" ]; then
      warn "extra source files in $CHRONY_DIR (${stray# }) add to the shipped default instead of replacing it - only ntp.sources replaces it"
    fi
  fi
fi

echo ""

# ------------------------------------------------------------------
# Summary
# ------------------------------------------------------------------
echo "============================================"
TOTAL=$((PASS + WARN + FAIL))
echo "  $PASS passed, $WARN warnings, $FAIL failed (of $TOTAL checks)"
echo "============================================"

if [ "$FAIL" -gt 0 ]; then
  exit 1
elif [ "$WARN" -gt 0 ]; then
  exit 0
else
  exit 0
fi
