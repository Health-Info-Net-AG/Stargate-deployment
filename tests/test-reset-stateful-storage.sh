#!/bin/bash
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "$here/../docker-compose/scripts" && pwd)"
root=/tmp/sg-reset-test; rm -rf "$root"; export STARGATE_DATA_DIR="$root"
# source restore.sh's dependencies + the function under test without running the whole script
PROJECT_DIR="$SCRIPTS_DIR/.."; SCRIPT_DIR="$SCRIPTS_DIR"
. "$SCRIPTS_DIR/lib/paths.sh"; . "$SCRIPTS_DIR/init-data-layout.sh"
# extract just the function body by sourcing restore.sh with a guard is overkill;
# instead assert the function exists once defined in restore.sh via a marker source:
# Seed stateful dirs + a dir that must be preserved, then call the function.
init_data_layout
echo OLD > "$root/vault/keys"; echo OLD > "$root/postgres/pg"; echo OLD > "$root/seaweedfs/obj"
echo KEEP > "$root/vereign/customer-config.sh"; echo KEEP > "$root/stalwart/mail"
# pull the function definition out of restore.sh and eval it (no full-script run)
eval "$(sed -n '/^reset_stateful_storage()/,/^}/p' "$SCRIPTS_DIR/restore.sh")"
reset_stateful_storage
[ ! -e "$root/vault/keys" ] && [ ! -e "$root/postgres/pg" ] && [ ! -e "$root/seaweedfs/obj" ] || { echo "FAIL: stateful not wiped"; exit 1; }
[ -d "$root/vault" ] && [ -d "$root/postgres" ] && [ -d "$root/seaweedfs" ] || { echo "FAIL: dirs not recreated"; exit 1; }
[ -f "$root/vereign/customer-config.sh" ] && [ -f "$root/stalwart/mail" ] || { echo "FAIL: preserved data wrongly wiped"; exit 1; }
echo "PASS"
