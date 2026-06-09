#!/bin/bash
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$PROJECT_DIR/customer-config.sh"

. "$SCRIPT_DIR/lib/env.sh"

cd "$PROJECT_DIR"

echo "Stopping all services..."
docker compose stop

# Stop Dozzle if enabled
if [ -f "$CONFIG_FILE" ]; then
  DOZZLE_ENABLED_VALUE=$(read_env_var DOZZLE_ENABLED "$CONFIG_FILE")
  if [ "$DOZZLE_ENABLED_VALUE" = "true" ]; then
    docker compose --profile dozzle stop 2>/dev/null || true
  fi
fi

echo ""
echo "All services stopped. Data volumes preserved."
echo ""
echo "To start again:        ./scripts/start.sh"
echo "To delete all data:    ./scripts/purge.sh"
echo ""
