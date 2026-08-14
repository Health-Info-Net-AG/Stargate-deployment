#!/bin/bash
# =============================================================================
# Assert that init-data-layout.sh (and other write-producing setup steps) never
# write anything under the read-only docker-compose/ tree.
#
# In production the docker-compose/ directory is a read-only bootc image
# layer, so any script that tries to write into it (instead of under
# STARGATE_DATA_DIR / /var/data) would fail at runtime. This is a fast,
# docker-daemon-free smoke test for that guarantee.
# =============================================================================
set -euo pipefail
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
marker=/tmp/sg-ro-marker; touch "$marker"; sleep 1
export STARGATE_DATA_DIR=/tmp/sg-ro-data; rm -rf "$STARGATE_DATA_DIR"
# Simulate the write-producing steps that don't need a live docker daemon:
bash "$repo/docker-compose/scripts/init-data-layout.sh"
# Nothing under docker-compose/ may be newer than the marker:
changed="$(find "$repo/docker-compose" -type f -newer "$marker" -not -path '*/.git/*' 2>/dev/null || true)"
[ -z "$changed" ] || { echo "FAIL: compose tree written:"; echo "$changed"; exit 1; }
echo "PASS"
