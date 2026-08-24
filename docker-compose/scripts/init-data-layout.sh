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
  # DATA_DIR (/var/data) is normally a dedicated Data Disk (VEREIGN-DATA) mounted by
  # the appliance's var-data.mount (ADR-0004). If that disk is absent -- an older/
  # single-disk VM, or a manual install.sh after purge.sh on hardware with no second
  # drive -- /var/data is just a directory on the boot disk. That single-disk fallback
  # is intended ONLY for a MANUAL install.sh run. On the automated first-boot path the
  # units already Require=var-data.mount (verimesh-install / verimesh-data-layout), so
  # they never reach here without a disk; and should init-data-layout ever be invoked
  # automatically with no disk, we REFUSE rather than silently scatter all writable
  # state (config, secrets, databases, mail, object store) onto the boot disk. Skipped
  # entirely when STARGATE_DATA_DIR overrides the root (local testing).
  if [ -z "${STARGATE_DATA_DIR:-}" ] && ! mountpoint -q "$DATA_DIR" 2>/dev/null; then
    # Automated iff running under a systemd service (cgroup .../system.slice/<name>.service);
    # a manual run lives in an interactive user-session .scope. /proc/self/cgroup is always
    # readable; if it somehow isn't, we fall through to the manual warning below (the automated
    # boot path is separately gated by the units' Requires=var-data.mount, so it can't reach here
    # without a disk anyway).
    if grep -qE '/system\.slice/[^/]*\.service' /proc/self/cgroup 2>/dev/null; then
      echo "ERROR: no data disk mounted at $DATA_DIR on an automated run -- refusing to fall back to" >&2
      echo "       the boot disk. Attach a VEREIGN-DATA disk. (Single-disk fallback is manual-install only.)" >&2
      return 1
    fi
    echo "WARNING: no dedicated data disk mounted at $DATA_DIR -- falling back to the filesystem in boot disk." >&2
    echo "         All Stargate state will live on the boot disk. This is fine for single-disk VMs;" >&2
    echo "         attach a VEREIGN-DATA disk to keep state on a separate, independently sized volume." >&2
  fi

  mkdir -p \
    "$SECRETS_DIR" "$TLS_DIR" "$KEYCLOAK_GEN_DIR" "$APISIX_GEN_DIR" "$BACKUP_DIR" \
    "$DATA_DIR/postgres" "$DATA_DIR/vault" "$DATA_DIR/seaweedfs" "$DATA_DIR/stalwart" \
    "$DATA_DIR/clamav" "$DATA_DIR/loki" "$DATA_DIR/alloy" "$DATA_DIR/textfile_collector" \
    "$DATA_DIR/dashboard_cache" "$DATA_DIR/restore" \
    "$DATA_DIR/idagent" "$DATA_DIR/watcher"

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
  chown 1001:1001  "$DATA_DIR/idagent"         # idagent KERI redb cache at /data/keri (uid 1001)
  # postgres self-chowns (entrypoint runs as root); seaweedfs/alloy/textfile/watcher run as root.
}

# Allow both `source init-data-layout.sh` (defines init_data_layout) and direct
# execution (runs it).
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  init_data_layout
fi
