#!/bin/bash
# shellcheck disable=SC2034
# =============================================================================
# Shared library: canonical locations of all machine-local WRITABLE state.
#
# Sourced by host bash scripts -- NOT meant to be executed directly. Callers
# must define SCRIPT_DIR and PROJECT_DIR (the read-only docker-compose/ dir)
# before sourcing, exactly as they already do before sourcing lib/env.sh.
#
# The docker-compose/ tree is READ-ONLY at runtime (bootc image layer). Every
# path here resolves under DATA_DIR (the /var/data Data Disk, ADR-0004);
# STARGATE_DATA_DIR overrides the root for local testing.
# =============================================================================

DATA_DIR="${STARGATE_DATA_DIR:-/var/data}"
VEREIGN_DIR="$DATA_DIR/vereign"

ENV_FILE="$VEREIGN_DIR/.env"
CONFIG_FILE="$VEREIGN_DIR/customer-config.sh"
SECRETS_DIR="$VEREIGN_DIR/secrets"
TLS_DIR="$VEREIGN_DIR/tls"
KEYCLOAK_GEN_DIR="$VEREIGN_DIR/keycloak"
APISIX_GEN_DIR="$VEREIGN_DIR/apisix"
UPDATE_LOG="$VEREIGN_DIR/update.log"
BACKUP_DIR="$DATA_DIR/backups"

# Canonical compose invocation. PROJECT_DIR is the read-only docker-compose/
# dir the caller lives under (/usr/share/... on bootc, the git checkout on
# manual installs); --env-file points at the relocated .env so bare `docker
# compose` no longer needs a .env next to the compose file.
#
# DEV/TEST override: if a writable docker-compose.override.yml (or .yaml) exists under
# $VEREIGN_DIR, layer it on top of the read-only baked docker-compose.yml so its keys deep-merge
# over the base (`docker compose -f base -f override` semantics). This is meant for development
# and testing only: it is NOT covered by the offline image bake (an override that changes/adds an
# image needs a runtime pull) and it persists across bootc rollback. When no such file exists,
# behaviour is identical to before. Relative paths inside the override resolve against
# --project-directory ($PROJECT_DIR), so reference any host files by absolute path.
#
# Because it silently changes the compose graph for every command below (install/update/start/
# stop/purge/backup), compose() prints a one-time stderr notice while an override is active.
# Also note: /var/data is in backup scope, so an override created on a test box travels inside a
# backup archive; on restore it applies on the target -- the switch/rollback guard retires it only
# when restored onto a DIFFERENT image (stamp mismatch), not onto the same image version.
compose() {
  # Accept either extension -- docker compose treats .yml and .yaml as equivalent, and a wrong
  # guess should not silently no-op. .yml wins if both exist (matches the base docker-compose.yml).
  local override="" f
  for f in "$VEREIGN_DIR/docker-compose.override.yml" "$VEREIGN_DIR/docker-compose.override.yaml"; do
    [ -f "$f" ] && { override="$f"; break; }
  done
  if [ -n "$override" ]; then
    # Announce once per process (global flag, not per compose() call -- this runs many times
    # per script) so an active dev/test override is never silently in effect.
    if [ -z "${_COMPOSE_OVERRIDE_ANNOUNCED:-}" ]; then
      echo "compose: using dev/test override $override (layered over the baked docker-compose.yml)" >&2
      _COMPOSE_OVERRIDE_ANNOUNCED=1
    fi
    docker compose --project-directory "$PROJECT_DIR" --env-file "$ENV_FILE" \
      -f "$PROJECT_DIR/docker-compose.yml" -f "$override" "$@"
  else
    docker compose --project-directory "$PROJECT_DIR" --env-file "$ENV_FILE" "$@"
  fi
}
