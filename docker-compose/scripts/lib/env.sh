#!/bin/bash
# =============================================================================
# Shared library: read a single KEY=value from a .env / customer-config file.
#
# Sourced by host bash scripts -- NOT meant to be executed directly.
#
# Why not just `source` the file? Docker Compose .env files use shell-like
# KEY=VALUE syntax but do NOT require quoting values that contain spaces or
# shell metacharacters. Sourcing such a file makes bash interpret the unquoted
# tail as a command (e.g. `WG_PEER_DESCRIPTION=WireGuard peer connection` ->
# bash tries to run `peer connection`), which under `set -e` aborts the script.
# read_env_var reads one key without those side effects.
# =============================================================================

# read_env_var KEY FILE -> prints the value of KEY (last occurrence) on stdout,
# with a single pair of surrounding single/double quotes stripped. Prints
# nothing (and still succeeds) if FILE is missing or KEY is absent.
read_env_var() {
  local key="$1" file="$2" line value
  [ -f "$file" ] || return 0
  line=$(grep -E "^${key}=" "$file" 2>/dev/null | tail -1) || return 0
  [ -n "$line" ] || return 0
  value="${line#"${key}"=}"
  # Strip a single pair of surrounding double or single quotes if present.
  if [[ "$value" =~ ^\".*\"$ ]]; then
    value="${value#\"}"
    value="${value%\"}"
  elif [[ "$value" =~ ^\'.*\'$ ]]; then
    value="${value#\'}"
    value="${value%\'}"
  fi
  printf '%s' "$value"
}
