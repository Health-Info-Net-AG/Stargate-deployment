#!/bin/bash
set -eo pipefail

# ==============================================================================
# Stargate Update Script
# ==============================================================================
# Re-reads customer-config.sh, regenerates .env, and restarts all services.
# Can also jump the deployment repo itself to a specific tested release.
#
# Use cases:
#   - Update mail domains, WireGuard config, or any other customer settings
#   - Change passwords or credentials (except VAULT_TOKEN, which is preserved)
#   - Jump straight to a released version, including installs several
#     versions behind: --release <tag> (image versions are pinned in that
#     release's docker-compose.yml, not in this config)
#
# Usage:
#   ./scripts/update.sh                    # regenerate .env and restart
#   ./scripts/update.sh --env-only         # regenerate .env without restarting
#   ./scripts/update.sh --list-releases    # show available release tags
#   ./scripts/update.sh --release <tag> [--skip-backup]
#                                          # update the deployment repo to
#                                          # <tag> (whose docker-compose.yml
#                                          # carries the pinned image versions;
#                                          # a backup is taken first unless
#                                          # --skip-backup is given), then run
#                                          # the normal update flow below
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
. "$SCRIPT_DIR/lib/paths.sh"

# Mirror this run's stdout+stderr into $UPDATE_LOG (in addition to the
# terminal), so a failed update is diagnosable from the log file alone --
# picked up by send-logs-to-support.sh -- without needing to have been
# watched live. Guarded so this is a no-op on the internal re-exec that
# --release performs after checking out the target tag (below): that
# re-exec'd process inherits the already-redirected stdout/stderr rather than
# attaching a second tee on top.
if [ -z "${STARGATE_UPDATE_LOG_ACTIVE:-}" ]; then
  export STARGATE_UPDATE_LOG_ACTIVE=1
  exec > >(tee -a "$UPDATE_LOG") 2>&1
fi

echo "$(date -Iseconds) update.sh invoked: $0 $*"

# Source install.sh for shared functions (load_customer_config, generate_env_file, etc.)
STARGATE_SOURCE_ONLY=1 source "$SCRIPT_DIR/install.sh"
. "$SCRIPT_DIR/lib/env.sh"
. "$SCRIPT_DIR/lib/config-sync.sh"
. "$SCRIPT_DIR/lib/manifest.sh"

# Parse arguments. ENV_ONLY defaults from STARGATE_UPDATE_ENV_ONLY so that
# `--release <tag> --env-only` survives the flag-less re-exec below: without
# this, the re-exec'd process would always fall through to a full restart,
# silently ignoring --env-only rather than doing what was actually asked
# (stage the release's config/versions without restarting yet).
ENV_ONLY="${STARGATE_UPDATE_ENV_ONLY:-false}"
SKIP_BACKUP=false
RELEASE_TAG=""
LIST_RELEASES=false
while [ "$#" -gt 0 ]; do
  case "$1" in
    --env-only)
      ENV_ONLY=true
      shift
      ;;
    --skip-backup)
      SKIP_BACKUP=true
      shift
      ;;
    --release)
      RELEASE_TAG="${2:-}"
      if [ -z "$RELEASE_TAG" ]; then
        echo "ERROR: --release requires a tag argument, e.g. --release v0.5.3"
        exit 1
      fi
      shift 2
      ;;
    --list-releases)
      LIST_RELEASES=true
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [--env-only] [--release <tag> [--skip-backup]] [--list-releases]"
      echo ""
      echo "  --env-only        Regenerate .env without restarting services"
      echo "  --release <tag>   Update the deployment repo to <tag> and apply that"
      echo "                    release's tested app versions, then run the normal"
      echo "                    update flow. Takes a backup first unless"
      echo "                    --skip-backup is given."
      echo "  --skip-backup     Skip the pre-update backup (only with --release)"
      echo "  --list-releases   List available release tags"
      echo ""
      echo "With no flags: edit customer-config.sh first, then run this script to"
      echo "apply changes."
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [--env-only] [--release <tag>] [--list-releases]"
      exit 1
      ;;
  esac
done

cd "$PROJECT_DIR"

if [ "$LIST_RELEASES" = true ]; then
  echo "Fetching available releases from origin..."
  if ! manifest_git_fetch_origin; then
    echo "ERROR: could not fetch from 'origin' -- check network/remote access."
    exit 1
  fi
  echo ""
  echo "Recent release tags (most recent first). '(manifest available)' means"
  echo "'--release <tag>' can be used today; '(no manifest yet)' means the"
  echo "release's manifest MR hasn't been merged to main yet."
  echo ""
  while read -r t; do
    [ -n "$t" ] || continue
    if manifest_exists "$t"; then
      echo "  $t  (manifest available)"
    else
      echo "  $t  (no manifest yet)"
    fi
  done < <(git tag --sort=-creatordate | head -20)
  TOTAL=$(git tag | wc -l)
  echo ""
  echo "Showing 20 most recent of $TOTAL total tags. Run 'git tag' for the full list."
  exit 0
fi

if [ -n "$RELEASE_TAG" ]; then
  echo "============================================"
  echo "  Release update: $RELEASE_TAG"
  echo "============================================"
  echo ""

  echo "=== Fetching release manifest ==="
  MANIFEST_JSON="$(manifest_fetch_json "$RELEASE_TAG")"
  echo "  Manifest found for $RELEASE_TAG."
  echo ""

  # Captured before anything is touched, purely for the backup label below.
  CURRENT_VERSION="$(detect_app_version "$PROJECT_DIR")"

  if [ "$SKIP_BACKUP" = true ]; then
    echo "=== Skipping backup (--skip-backup) ==="
  else
    echo "=== Backing up before update (this can take a few minutes) ==="
    "$SCRIPT_DIR/backup.sh" --label "${CURRENT_VERSION}-pre_update"
  fi
  echo ""

  echo "=== Versions shipped by $RELEASE_TAG (pinned in that tag's docker-compose.yml) ==="
  manifest_show_images "$MANIFEST_JSON"
  echo ""

  echo "=== Updating deployment repo to $RELEASE_TAG ==="
  # Force past any local edits to tracked files (e.g. a hand-patched
  # docker-compose.yml) -- git is the single source of truth here, matching
  # the fix already applied to the ops-agent's own GitPull. Same
  # non-interactive guards as manifest_git_fetch_origin, so an unreachable
  # remote or a hidden prompt fails fast instead of hanging.
  if ! GIT_TERMINAL_PROMPT=0 \
       GIT_SSH_COMMAND='ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10' \
       timeout "$MANIFEST_GIT_TIMEOUT" git checkout -f "$RELEASE_TAG" </dev/null; then
    echo "ERROR: git checkout of $RELEASE_TAG failed or timed out."
    echo "Nothing has been changed -- the deployment repo is still on its previous"
    echo "revision (image versions live in the tag's docker-compose.yml, delivered by"
    echo "this checkout). Re-running '$0 --release $RELEASE_TAG' is safe and will retry."
    exit 1
  fi
  echo ""

  echo "Continuing update as release $RELEASE_TAG..."
  echo ""
  # Re-exec a FRESH copy of this script (now checked out at $RELEASE_TAG),
  # with NO flags. This is deliberate, not incidental: the checkout above just
  # rewrote this very file on disk out from under the running process, and a
  # bash script cannot safely keep executing inline once its own source file
  # has changed underneath it (the same reasoning behind the ops-agent
  # splitting GitPull from a separately-launched RunUpdateScript, rather than
  # continuing in-process after the checkout). The checkout above already brought
  # $RELEASE_TAG's docker-compose.yml (with its pinned image versions), so the
  # freshly re-exec'd plain `update.sh` does exactly the right thing with its own
  # -- possibly different -- code, whether $RELEASE_TAG is newer or older than
  # what was running a moment ago. STARGATE_UPDATE_RELEASE is
  # passed through only so the continued run's banner below can still name
  # the release; it has no effect on control flow, so this remains correct
  # even against a $RELEASE_TAG whose update.sh predates this flag entirely.
  # STARGATE_UPDATE_ENV_ONLY carries the original --env-only choice through
  # the same way, so `--release <tag> --env-only` actually stops after
  # regenerating .env instead of silently doing a full restart.
  export STARGATE_UPDATE_RELEASE="$RELEASE_TAG"
  export STARGATE_UPDATE_ENV_ONLY="$ENV_ONLY"
  exec "$SCRIPT_DIR/update.sh"
fi

echo "============================================"
echo "  Stargate Configuration Update"
if [ -n "${STARGATE_UPDATE_RELEASE:-}" ]; then
  echo "  (continuing --release $STARGATE_UPDATE_RELEASE)"
fi
echo "============================================"
echo ""

# Preserve VAULT_TOKEN from current .env (tied to Vault unseal state)
EXISTING_VAULT_TOKEN=""
if [ -f "$ENV_FILE" ]; then
  EXISTING_VAULT_TOKEN=$(read_env_var VAULT_TOKEN "$ENV_FILE")
fi

# Fall back to vault-keys.json if .env has no token. KEYS_FILE is already set
# (from the sourced install.sh) to "$SECRETS_DIR/vault-keys.json".
if [ -z "$EXISTING_VAULT_TOKEN" ] && [ -f "$KEYS_FILE" ]; then
  EXISTING_VAULT_TOKEN=$(jq -r '.root_token' "$KEYS_FILE" 2>/dev/null || true)
  if [ -n "$EXISTING_VAULT_TOKEN" ]; then
    echo "Recovered VAULT_TOKEN from vault-keys.json"
    echo ""
  fi
fi

if [ -z "$EXISTING_VAULT_TOKEN" ]; then
  echo "ERROR: No VAULT_TOKEN found in .env or vault-keys.json."
  echo "  Run init-vault.sh first, or re-run install.sh."
  exit 1
fi

# Load customer config (validates required fields, derives defaults)
load_customer_config

# Sync new variables from the example template into customer-config.sh
# (append-only - never overwrites existing values)
EXAMPLE_FILE="$(detect_example_file "$PROJECT_DIR" "$CONFIG_FILE")"
sync_customer_config "$EXAMPLE_FILE" "$CONFIG_FILE"

# Re-load config: sync_customer_config may have appended new variables from
# the template; load_customer_config re-sources the file AND re-derives
# defaults (e.g. KEYCLOAK_PUBLIC_URL from SERVER_STATIC_IP). A bare
# `source "$CONFIG_FILE"` would overwrite those derived values with the
# empty strings still in customer-config.sh.
load_customer_config

# Regenerate .env
generate_env_file

# Restore VAULT_TOKEN (generate_env_file writes it blank)
if [ -n "$EXISTING_VAULT_TOKEN" ]; then
  sed -i "s|^VAULT_TOKEN=.*|VAULT_TOKEN=\"$EXISTING_VAULT_TOKEN\"|" "$ENV_FILE"
  echo "Preserved VAULT_TOKEN from previous .env"
  echo ""
fi

if [ "$ENV_ONLY" = true ]; then
  echo "Done. .env updated (--env-only, services not restarted)."
  echo ""
  echo "To apply changes: docker compose down && docker compose up -d"
  exit 0
fi

# Pull new images and restart changed services. Deliberately NOT --quiet:
# Compose's own per-service progress ("Pulling mxengine ... done") is exactly
# the visibility that was missing when diagnosing past update issues -- a
# silent multi-minute block here reads as a hang.
echo "=== Pulling images ==="
compose pull

echo ""
echo "=== Recreating services ==="
compose up -d --remove-orphans

# Handle Dozzle enable/disable and credential updates
update_dozzle() {
  local dozzle_enabled
  dozzle_enabled=$(read_env_var DOZZLE_ENABLED "$CONFIG_FILE")

  local dozzle_running
  dozzle_running=$(compose --profile dozzle ps --format '{{.Name}}' 2>/dev/null | grep -q stargate-dozzle && echo "true" || echo "false")

  if [ "$dozzle_enabled" != "true" ]; then
    if [ "$dozzle_running" = "true" ]; then
      echo ""
      echo "Dozzle disabled in config - stopping..."
      compose --profile dozzle down
    fi
    return 0
  fi

  # Dozzle is enabled - authentication is handled by oauth2-proxy -> Keycloak
  # (no local users.yml). Just (re)start the "dozzle" profile.
  echo ""
  echo "Starting Dozzle (behind oauth2-proxy -> Keycloak)..."
  compose --profile dozzle up -d
}

update_dozzle

# Clean up stale Docker resources (old images, orphaned volumes, build cache)
echo ""
echo "Cleaning up unused Docker resources..."
docker image prune -af --filter "until=24h" 2>/dev/null | tail -1 || true
docker volume prune -f 2>/dev/null | tail -1 || true
docker builder prune -af --keep-storage=1GB 2>/dev/null | tail -1 || true

echo ""
echo "============================================"
echo "  Update Complete"
echo "============================================"
echo ""
echo "  Changes applied from: $CONFIG_FILE"
echo "  Environment file:     $ENV_FILE"
if [ -n "${STARGATE_UPDATE_RELEASE:-}" ]; then
  echo "  Release:              $STARGATE_UPDATE_RELEASE"
fi
echo ""
echo "  Verify with: docker compose ps"
echo "  Full log:    $UPDATE_LOG"
echo ""
