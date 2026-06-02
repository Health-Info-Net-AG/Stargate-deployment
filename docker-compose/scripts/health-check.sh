#!/bin/bash
# ==============================================================================
# Stargate Health Check
# ==============================================================================
# Performs a comprehensive health check of all Stargate services.
# Exit code: 0 = all healthy, 1 = one or more issues found.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$PROJECT_DIR/.env"

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
  stargate-minio
  stargate-smimekeys-client
  stargate-policy
  stargate-irisagent
  stargate-mxengine
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

# Load VAULT_TOKEN from .env
VAULT_TOKEN=""
if [ -f "$ENV_FILE" ]; then
  VAULT_TOKEN=$(grep "^VAULT_TOKEN=" "$ENV_FILE" | cut -d= -f2-)
fi

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

pg_ready=$(docker exec stargate-postgres pg_isready -U postgres 2>/dev/null)
if [ $? -eq 0 ]; then
  pass "PostgreSQL accepting connections"
else
  fail "PostgreSQL not ready"
fi

for db in smimekeys_client policy irisagent mxengine; do
  count=$(docker exec stargate-postgres psql -U postgres -d "$db" -tAc "SELECT 1" 2>/dev/null)
  if [ "$count" = "1" ]; then
    pass "Database: $db"
  else
    fail "Database: $db (cannot connect)"
  fi
done

echo ""

# ------------------------------------------------------------------
# 5. MinIO
# ------------------------------------------------------------------
echo "--- MinIO ---"

minio_health=$(curl -sf --max-time 5 "http://localhost:9000/minio/health/live" 2>/dev/null)
if [ $? -eq 0 ]; then
  pass "MinIO live"
else
  fail "MinIO health check failed"
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

# Check management API reachable
stalwart_health=$(docker exec stargate-stalwart curl -sf http://127.0.0.1:8080/healthz 2>/dev/null)
if [ $? -eq 0 ]; then
  pass "Stalwart management API reachable"
else
  fail "Stalwart management API unreachable"
fi

# Check port 25 is listening
port25=$(docker exec stargate-stalwart sh -c 'ss -tlnp 2>/dev/null || netstat -tlnp 2>/dev/null' | grep ":25 ")
if [ -n "$port25" ]; then
  pass "Port 25 listening"
else
  fail "Port 25 not listening (provision may not have run yet)"
fi

# Check reinjection port 10026
port10026=$(docker exec stargate-stalwart sh -c 'ss -tlnp 2>/dev/null || netstat -tlnp 2>/dev/null' | grep ":10026 ")
if [ -n "$port10026" ]; then
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
  resp=$(curl -sf --max-time 5 "http://localhost:${port}/metrics" 2>/dev/null | head -1)
  if [ $? -eq 0 ] || [ -n "$resp" ]; then
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

# Host disk usage
disk_pct=$(df -h / 2>/dev/null | awk 'NR==2{print $5}' | tr -d '%')
if [ -n "$disk_pct" ]; then
  if [ "$disk_pct" -ge 90 ]; then
    fail "Root disk ${disk_pct}% full"
  elif [ "$disk_pct" -ge 80 ]; then
    warn "Root disk ${disk_pct}% full"
  else
    pass "Root disk ${disk_pct}% used"
  fi
fi

# Memory
mem_info=$(free -h 2>/dev/null | awk 'NR==2{printf "%s used / %s total (%s available)", $3, $2, $7}')
if [ -n "$mem_info" ]; then
  echo "  [INFO] Memory: $mem_info"
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
