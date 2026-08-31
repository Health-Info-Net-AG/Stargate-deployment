#!/bin/bash
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "$here/../docker-compose/scripts" && pwd)"
PROJECT_DIR=/opt/fake/docker-compose
SCRIPT_DIR="$PROJECT_DIR/scripts"
STARGATE_DATA_DIR=/tmp/sg-paths-test
. "$SCRIPTS_DIR/lib/paths.sh"
[ "$DATA_DIR" = /tmp/sg-paths-test ] || { echo "DATA_DIR wrong: $DATA_DIR"; exit 1; }
[ "$ENV_FILE" = /tmp/sg-paths-test/vereign/.env ] || { echo "ENV_FILE wrong: $ENV_FILE"; exit 1; }
[ "$CONFIG_FILE" = /tmp/sg-paths-test/vereign/customer-config.sh ] || { echo "CONFIG_FILE wrong"; exit 1; }
[ "$SECRETS_DIR" = /tmp/sg-paths-test/vereign/secrets ] || { echo "SECRETS_DIR wrong"; exit 1; }
[ "$BACKUP_DIR" = /tmp/sg-paths-test/backups ] || { echo "BACKUP_DIR wrong"; exit 1; }
[ "$UPDATE_LOG" = /tmp/sg-paths-test/vereign/update.log ] || { echo "UPDATE_LOG wrong"; exit 1; }
[ "$CHRONY_DIR" = /tmp/sg-paths-test/vereign/chrony ] || { echo "CHRONY_DIR wrong: $CHRONY_DIR"; exit 1; }
[ "$CHRONY_SOURCES_FILE" = /tmp/sg-paths-test/vereign/chrony/ntp.sources ] || { echo "CHRONY_SOURCES_FILE wrong: $CHRONY_SOURCES_FILE"; exit 1; }
type compose >/dev/null || { echo "compose() not defined"; exit 1; }
echo "PASS"
