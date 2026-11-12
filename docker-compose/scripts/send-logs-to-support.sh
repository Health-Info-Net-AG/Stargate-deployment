#!/bin/bash
set -euo pipefail

# You can use following Arguments or combinations of them:
#   --tail 500 - last 500 lines of logs for each container
#   --since 1h - all logs since 1 hour
#   --until 5m - Show logs before a timestamp or relative (e.g. 42m for 42 minutes)
#   --all      - all logs, could be too big to upload
# Please refer to https://docs.docker.com/reference/cli/docker/container/logs/#options

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC2034 # required by lib/paths.sh's calling convention, unused directly here
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
. "$SCRIPT_DIR/lib/paths.sh"

if [[ " $* " == *" --all "* ]]; then
    args=()   # no tail/since/until restrictions
elif [ "$#" -eq 0 ]; then
    # Default argument
    args=(--tail 500)
else
    args=("$@")
fi

TEMP_FILE="/tmp/docker_logs.tmp"
LIMIT_MB=20
LIMIT_BYTES=$((LIMIT_MB * 1024 * 1024))

echo "We will collect logs now with following arguments: ${args[*]}"

# Add timestamp when logs were collected, overwrite if file exist
echo -e "$(date -Ins)\n\n######\n" > "$TEMP_FILE"
# Add Information about current version and containers
echo "$(docker ps -a)" >> "$TEMP_FILE"
echo -e "\n######\n" >> "$TEMP_FILE"

# Add Information about host machine
echo -e "\n# CPU\n" >> "$TEMP_FILE"
echo "nproc output: $(nproc)" >> "$TEMP_FILE"
lscpu | grep -E "Model name|CPU MHz|CPU\(s\)|Thread" >> "$TEMP_FILE"

echo -e "\n# NETWORK\n" >> "$TEMP_FILE"
# Prefer nmcli, then resolvectl+ip addr, then plain ip addr -- whichever
# network stack is actually present (NetworkManager, systemd-networkd, or
# neither). Guarded with `command -v` and `|| true`/`|| echo` throughout: an
# absent tool must never abort the whole script under set -e/pipefail (it
# previously did -- a host with neither nmcli nor resolvectl installed would
# die here before ever reaching the container logs below).
DEFAULT_IFACE="$(ip route show default 2>/dev/null | awk '{print $5; exit}')"
if [ -z "$DEFAULT_IFACE" ]; then
  echo "(no default route found)" >> "$TEMP_FILE"
elif command -v nmcli >/dev/null 2>&1; then
  nmcli device show "$DEFAULT_IFACE" >> "$TEMP_FILE" 2>&1 || echo "(nmcli failed)" >> "$TEMP_FILE"
elif command -v resolvectl >/dev/null 2>&1; then
  { resolvectl status 2>&1 | grep "DNS Servers"; ip addr show "$DEFAULT_IFACE" 2>&1; } >> "$TEMP_FILE" || true
else
  echo "(nmcli/resolvectl not available; showing interface only)" >> "$TEMP_FILE"
  ip addr show "$DEFAULT_IFACE" >> "$TEMP_FILE" 2>&1 || true
fi
ip route >> "$TEMP_FILE"

echo -e "\n# RAM\n" >> "$TEMP_FILE"
free -h >> "$TEMP_FILE"

echo -e "\n# Disk: size and type (rotational=1 means HDD, 0 means SSD)\n" >> "$TEMP_FILE"
df -hT /  >> "$TEMP_FILE"
lsblk -d -o NAME,SIZE,ROTA,MODEL  >> "$TEMP_FILE"
echo -e "\n######\n" >> "$TEMP_FILE"

# Add update.sh's own status/history -- whether an update is still in-flight
# (systemd scope launched by the ops-agent's RunUpdateScript, or by a manual
# ./scripts/update.sh --release run) vs. dead, and what update.sh itself
# logged. This is the single piece that's needed to diagnose "the update
# started but nothing happened" without a second round-trip asking for it.
echo -e "\n# UPDATE STATUS\n" >> "$TEMP_FILE"
systemctl status stargate-update.scope >> "$TEMP_FILE" 2>&1 || true
echo -e "\n# update.log\n" >> "$TEMP_FILE"
if [ -f "$UPDATE_LOG" ]; then
  cat "$UPDATE_LOG" >> "$TEMP_FILE"
else
  echo "(no update.log -- no update has been run yet)" >> "$TEMP_FILE"
fi
echo -e "\n######\n" >> "$TEMP_FILE"

# bootc appliance only: OS versions and the boot-time units. The ops-agent log is lost when its
# container is recreated at boot, so these are what show whether an update failed after the reboot.
# The previous boot is included because after a greenboot rollback the failed boot is boot -1.
run_as_root() {
  if [ "$(id -u)" -eq 0 ]; then "$@"; else sudo -n "$@"; fi
}
if command -v bootc >/dev/null 2>&1; then
  echo -e "\n# OS STATUS (bootc)\n" >> "$TEMP_FILE"
  run_as_root bootc status >> "$TEMP_FILE" 2>&1 || echo "(bootc status failed -- run this script with sudo)" >> "$TEMP_FILE"
  echo -e "\n# BOOT UNITS\n" >> "$TEMP_FILE"
  systemctl status stargate verimesh-preload-images greenboot-healthcheck --no-pager >> "$TEMP_FILE" 2>&1 || true
  for boot in 0 -1; do
    echo -e "\n# JOURNAL boot $boot (stargate, verimesh-preload-images, greenboot-healthcheck)\n" >> "$TEMP_FILE"
    run_as_root journalctl -b "$boot" -u stargate -u verimesh-preload-images -u greenboot-healthcheck \
      --no-pager -n 300 >> "$TEMP_FILE" 2>&1 || echo "(journalctl failed -- run this script with sudo)" >> "$TEMP_FILE"
  done
  echo -e "\n######\n" >> "$TEMP_FILE"
fi

while IFS= read -r container; do
    docker logs "${args[@]}" --timestamps "$container" 2>&1 |
    sed "s/^/[$container] /"
done < <(docker ps -a --format '{{.Names}}') >> "$TEMP_FILE"

FILE_SIZE=$(stat -c%s "$TEMP_FILE" 2>/dev/null || stat -f%z "$TEMP_FILE")

if [ "$FILE_SIZE" -lt "$LIMIT_BYTES" ]; then

    # -k skips certificate verification. Customer networks commonly run a
    # TLS-inspecting proxy whose private CA is not in the host trust store, so
    # curl failed with "unable to get local issuer certificate" (exit 60) and
    # -- under set -e -- aborted the script before the cleanup below, leaving
    # the operator with no URL and no hint that the logs were already on disk.
    # The upload is still encrypted; we just don't authenticate the endpoint.
    # Note --retry never retries TLS/certificate errors, only transient ones.
    if curl -fsSk --retry 3 --retry-delay 5 "https://pastebin.hin-infra.ch/" \
        --data-binary "@$TEMP_FILE"; then
        echo -e "\nPlease provide this URL to support, all logs are saved here."
        rm -f "$TEMP_FILE"
    else
        echo -e "\nUpload failed. The logs are saved at $TEMP_FILE --" \
                "please attach that file to your support email." >&2
        exit 1
    fi

else
    echo -e "Log file is too big to be uploaded, please try to reduce it by adding additional arguments like\n '--since 1h' all logs since 1 hour, or\n '--tail 500' last 500 lines of logs for each container"
    exit 1
fi

exit 0