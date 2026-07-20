#!/bin/bash
# =============================================================================
# Shared library: fetch, validate, and apply a release manifest.
#
# Sourced by update.sh -- NOT meant to be executed directly.
# Requires read_env_var() from lib/env.sh to already be sourced.
#
# A release manifest (manifests/<tag>.json in the deployment repo) pins the
# tested combination of *_VERSION values shipped for that release. It is
# committed to `main` by CI *after* the release tag is cut (via a gated MR),
# so it is never present in the tag's own tree -- it must always be read from
# `origin/main`, regardless of whether `origin` is the internal GitLab repo or
# the public GitHub mirror (both verified to carry identical tags/main
# content).
# =============================================================================

# Same image-tag pattern the ops-agent enforces server-side before writing a
# dashboard-driven update's versions (stargate-ops internal/ops/executor.go).
# Applied here too because manifest values are about to be written into
# customer-config.sh, which is later `source`d -- a value containing shell
# metacharacters must be rejected, not written.
MANIFEST_IMAGE_TAG_REGEX='^[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}$'
# Every version key in every manifest observed so far follows this shape.
MANIFEST_KEY_REGEX='^[A-Z][A-Z0-9]*(_[A-Z0-9]+)*_VERSION$'
# Bounds how long a single git network operation (fetch/checkout) can run.
MANIFEST_GIT_TIMEOUT="${MANIFEST_GIT_TIMEOUT:-300}"

# manifest_git_fetch_origin -> fetches origin (branches + tags), strictly
# non-interactively and under a timeout, so an unreachable remote or a git
# process wedged on a hidden credential/host-key prompt cannot hang this
# script forever -- update.sh can run non-interactively (cron, or invoked by
# the ops-agent), where nothing is present to answer such a prompt. Same
# guards as the fix applied to the ops-agent's GitPull (stargate-ops
# internal/ops/executor.go): GIT_TERMINAL_PROMPT=0 (no HTTPS credential
# prompt), BatchMode=yes (no SSH password prompt), StrictHostKeyChecking=
# accept-new (no blocking yes/no on an unknown host key), ConnectTimeout, and
# an overall `timeout` as a backstop.
manifest_git_fetch_origin() {
  GIT_TERMINAL_PROMPT=0 \
  GIT_SSH_COMMAND='ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10' \
  timeout "$MANIFEST_GIT_TIMEOUT" git fetch origin --tags --force --quiet </dev/null
}

# manifest_fetch_json TAG -> prints the manifest JSON for TAG on stdout.
# Fetches origin (branches + tags) first. Fails with a clear message if the
# tag doesn't exist, if its manifest hasn't been merged to main yet, or if
# the manifest content isn't valid JSON with an .images object.
manifest_fetch_json() {
  local tag="$1"

  if ! manifest_git_fetch_origin; then
    echo "ERROR: could not fetch from 'origin' -- check network/remote access, or git may be waiting on a credential/host-key prompt (timed out after ${MANIFEST_GIT_TIMEOUT}s)." >&2
    return 1
  fi

  local json
  if ! json="$(git show "origin/main:manifests/${tag}.json" 2>/dev/null)"; then
    echo "ERROR: no manifest found for release '${tag}' at origin/main:manifests/${tag}.json" >&2
    echo "  Either the tag doesn't exist, or its manifest MR hasn't been merged to main yet." >&2
    echo "  Run '$0 --list-releases' to see which releases are available." >&2
    return 1
  fi

  if ! printf '%s' "$json" | jq -e '.images | type == "object"' >/dev/null 2>&1; then
    echo "ERROR: manifest for '${tag}' is not valid JSON with an 'images' object." >&2
    return 1
  fi

  printf '%s' "$json"
}

# manifest_exists TAG -> returns 0 if a manifest is available for TAG, 1
# otherwise. Assumes origin has already been fetched (does not fetch itself,
# so a caller checking many tags -- e.g. --list-releases -- only fetches once).
manifest_exists() {
  local tag="$1"
  git cat-file -e "origin/main:manifests/${tag}.json" 2>/dev/null
}

# manifest_apply_images MANIFEST_JSON CONFIG_FILE -> writes each KEY=value in
# MANIFEST_JSON's .images to CONFIG_FILE (sed-replace if the key exists,
# newline-guarded append if not -- mirrors the persist_secret fix, so a value
# can never merge onto the config's previous line). Prints a "KEY: old ->
# new" line for every value that actually changes; skips unchanged keys.
# Aborts (non-zero) on the first key/value that fails validation, before
# writing anything for that entry.
manifest_apply_images() {
  local manifest_json="$1" config="$2"
  local changed=0

  while IFS=$'\t' read -r key value; do
    [ -n "$key" ] || continue

    if ! [[ "$key" =~ $MANIFEST_KEY_REGEX ]]; then
      echo "ERROR: manifest key '${key}' doesn't look like a *_VERSION key -- refusing to apply." >&2
      return 1
    fi
    if ! [[ "$value" =~ $MANIFEST_IMAGE_TAG_REGEX ]]; then
      echo "ERROR: manifest value '${value}' for key '${key}' is not a valid image tag -- refusing to apply." >&2
      return 1
    fi

    local old
    old="$(read_env_var "$key" "$config")"

    if [ "$old" = "$value" ]; then
      continue
    fi

    if grep -q "^${key}=" "$config"; then
      sed -i "s|^${key}=.*|${key}=\"${value}\"|" "$config"
    else
      # Ensure a trailing newline before appending, so the new assignment
      # can't merge onto the config's last existing line (the bug that broke
      # a customer's update when NODE_EXPORTER_VERSION merged with a
      # subsequently-appended secret).
      if [ -s "$config" ] && [ "$(tail -c1 "$config")" != "" ]; then
        printf '\n' >> "$config"
      fi
      printf '%s="%s"\n' "$key" "$value" >> "$config"
    fi

    if [ -n "$old" ]; then
      echo "  ${key}: ${old} -> ${value}"
    else
      echo "  ${key}: (new) -> ${value}"
    fi
    changed=$((changed + 1))
  done < <(printf '%s' "$manifest_json" | jq -r '.images | to_entries[] | "\(.key)\t\(.value)"')

  if [ "$changed" -eq 0 ]; then
    echo "  No version changes -- already on this release's versions."
  else
    echo ""
    echo "  ${changed} version(s) updated."
  fi
}
