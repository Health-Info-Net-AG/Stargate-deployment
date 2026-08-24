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

# detect_app_version DIR -> prints the stargate-deployment release tag for the
# repo containing DIR (i.e. one level up from docker-compose/), or a short
# commit SHA if HEAD isn't tagged. Appends "-dirty" when the working tree has
# uncommitted changes. Prints "unknown" if .git is unavailable. Used by both
# install.sh (writes to .env) and start.sh (exports at runtime).
detect_app_version() {
  local project_dir="$1"
  local v
  v=$( cd "$project_dir/.." 2>/dev/null && \
       git describe --tags --always --dirty 2>/dev/null )
  printf '%s' "${v:-unknown}"
}

# read_env_var KEY FILE -> prints the value of KEY (last occurrence) on stdout,
# with a single pair of surrounding single/double quotes stripped. Prints
# nothing (and still succeeds) if FILE is missing or KEY is absent.
read_env_var() {
  local key="$1" file="$2" line value
  [ -f "$file" ] || return 0
  line=$(grep -E "^${key}=" "$file" 2>/dev/null | tail -1) || return 0
  [ -n "$line" ] || return 0
  value="${line#"${key}"=}"
  # Strip a single pair of surrounding double or single quotes if present,
  # ignoring any trailing inline comment (e.g. KEY=""  # comment).
  if [[ "$value" =~ ^\"([^\"]*)\" ]]; then
    value="${BASH_REMATCH[1]}"
  elif [[ "$value" =~ ^\'([^\']*)\' ]]; then
    value="${BASH_REMATCH[1]}"
  fi
  printf '%s' "$value"
}

# -----------------------------------------------------------------------------
# Ensure HOME (and XDG_CACHE_HOME) are set -- runs on source, before any script
# touches docker.
#
# rc.local, systemd units (e.g. the stargate ExecStart -> start.sh) and bare
# cron launch these scripts with an empty environment -- in particular no $HOME.
# Anything that resolves a cache/config dir from $XDG_CACHE_HOME or $HOME then
# fails: Go-based CLIs abort with "Could not find environment variable
# XDG_CACHE_HOME or HOME ...", and the docker CLI cannot read
# ~/.docker/config.json, so the authenticated Docker Hub pulls these scripts
# rely on break. Restore a sane HOME (the invoking user's, falling back to
# /root) when it is missing. Idempotent -- a no-op for interactive runs where
# HOME is already set.
# -----------------------------------------------------------------------------
if [ -z "${HOME:-}" ]; then
  # `|| true`: this is a bare assignment, so its exit status is the pipeline's.
  # Under `set -eo pipefail`, a uid with no passwd entry makes getent exit
  # non-zero (cut still exits 0) and would abort here -- on exactly the path
  # the /root fallback below exists to handle. Neutralize it so the fallback runs.
  HOME="$(getent passwd "$(id -u)" 2>/dev/null | cut -d: -f6)" || true
  export HOME="${HOME:-/root}"
fi
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
