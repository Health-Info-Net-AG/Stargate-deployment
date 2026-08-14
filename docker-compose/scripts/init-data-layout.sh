#!/bin/bash
# =============================================================================
# Create the /var/data layout and set per-service ownership.
#
# Runs as root in production (install.sh on manual installs; the bootc
# first-boot data-init unit on appliances). Single source of truth for the
# directory list + uid map. Idempotent. When not root, dirs are still created
# but chown is skipped with a warning (keeps it testable rootless).
#
# Bind mounts do NOT auto-chown the way Docker named volumes did on first init,
# so services that run as a fixed non-root uid need their dir pre-owned. uids
# verified from the pinned image configs (see the plan's uid table).
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
. "$SCRIPT_DIR/lib/paths.sh"

init_data_layout() {
  mkdir -p \
    "$SECRETS_DIR" "$TLS_DIR" "$KEYCLOAK_GEN_DIR" "$APISIX_GEN_DIR" "$BACKUP_DIR" \
    "$DATA_DIR/postgres" "$DATA_DIR/vault" "$DATA_DIR/seaweedfs" "$DATA_DIR/stalwart" \
    "$DATA_DIR/clamav" "$DATA_DIR/loki" "$DATA_DIR/alloy" "$DATA_DIR/textfile_collector" \
    "$DATA_DIR/dashboard_cache"

  # secrets/ holds Vault keys, WG/private material: keep it tight.
  chmod 700 "$SECRETS_DIR" 2>/dev/null || true

  if [ "$(id -u)" -ne 0 ]; then
    echo "init-data-layout: not root, skipping chown (dirs created, ownership unchanged)" >&2
    return 0
  fi

  # uid:gid verified from pinned image configs. Others run as root or self-heal.
  chown 100:1000   "$DATA_DIR/vault"           # hashicorp/vault (vault)
  chown 2000:2000  "$DATA_DIR/stalwart"        # stalwartlabs/stalwart (stalwart)
  chown 100:101    "$DATA_DIR/clamav"          # clamav/clamav (clamav)
  chown 10001:10001 "$DATA_DIR/loki"           # grafana/loki (10001)
  chown 1001:65533 "$DATA_DIR/dashboard_cache" # dashboard (nextjs)
  # postgres self-chowns (entrypoint runs as root); seaweedfs/alloy/textfile run as root.
}

# Allow both `source init-data-layout.sh` (defines init_data_layout) and direct
# execution (runs it).
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  init_data_layout
fi
