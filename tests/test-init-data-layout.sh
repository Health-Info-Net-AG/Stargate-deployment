#!/bin/bash
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "$here/../docker-compose/scripts" && pwd)"
root=/tmp/sg-layout-test; rm -rf "$root"
STARGATE_DATA_DIR="$root" bash "$SCRIPTS_DIR/init-data-layout.sh"
for d in vereign vereign/secrets vereign/tls vereign/keycloak vereign/apisix backups \
         postgres vault seaweedfs stalwart clamav loki alloy textfile_collector dashboard_cache \
         restore; do
  [ -d "$root/$d" ] || { echo "missing dir: $d"; exit 1; }
done
# Re-run must be idempotent (no error).
STARGATE_DATA_DIR="$root" bash "$SCRIPTS_DIR/init-data-layout.sh"
echo "PASS"
