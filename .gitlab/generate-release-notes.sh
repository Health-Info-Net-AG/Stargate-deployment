#!/usr/bin/env bash
# Generate release notes for a stargate-deployment release.

set -euo pipefail

TAG="${1:?usage: generate-release-notes.sh <tag>}"

# docker-compose.yml is the source of truth for shipped image versions: they are
# pinned there per git tag and delivered to a box by `git checkout <tag>`. These
# notes read the tag's own compose file, so they need no artifact from an earlier
# job and describe exactly what that tag ships.
COMPOSE_FILE="docker-compose/docker-compose.yml"
# Fallback for tags cut before versions moved into compose (up to v0.5.4-test2),
# whose compose used ${VAR} placeholders fed from these *_VERSION pins.
PROD_FILE="docker-compose/customer-config-prod.example.sh"

SEMVER_RE='^v[0-9]+\.[0-9]+\.[0-9]+$'              # v1.0.0 (manual milestones)

SVC_BASE="https://code.vereign.com/svdh"

service_repo() {   # first-party service NAME (no _VERSION) -> repo slug; empty otherwise
  case "$1" in
    SMIMEKEYS) echo smimekeys ;;
    POLICY|POLICY_SYNC) echo policy ;;
    IRISAGENT) echo irisagent ;;
    MXENGINE) echo mxengine ;;
    DASHBOARD) echo dashboard ;;
    MTACONF) echo mtaconf ;;
    *) echo "" ;;
  esac
}

is_semver() { printf '%s' "$1" | grep -Eq "$SEMVER_RE"; }

release_link() {   # $1=NAME $2=VERSION -> markdown cell
  local repo; repo="$(service_repo "$1")"
  if [ -n "$repo" ] && is_semver "$2"; then
    printf '[notes](%s/%s/-/releases/%s)' "$SVC_BASE" "$repo" "$2"
  else
    printf '—'
  fi
}

prev_tag() {   # $1=ref to walk back from -> nearest earlier semver tag
  git tag --merged "$1" --sort=-v:refname 2>/dev/null \
    | grep -E "$SEMVER_RE" | grep -Fvx "$TAG" | head -n1 || true
}

# Roll up since the previous semver tag.
PREV_TAG="$(prev_tag "$TAG")"

if [ -n "$PREV_TAG" ]; then
  RANGE="${PREV_TAG}..${TAG}"
else
  RANGE="$TAG" # no previous tag -> all history
fi

# Prefer the sha the pipeline actually built: a tag can be force-moved after the
# pipeline starts, in which case resolving the tag name reports a different
# commit than was released.
SHORT_SHA="$(git rev-parse --short "${CI_COMMIT_SHA:-$TAG}")"
SUBJECT="$(git log -1 --pretty=%s "${CI_COMMIT_SHA:-$TAG}")"

# parse_compose: stdin = docker-compose.yml -> "NAME<TAB>VERSION" lines. NAME is
# the image repo's last path segment, upper-cased with '-' -> '_', which lines up
# with the manifest keys the dashboard and ops-agent consume. First occurrence of
# a repo wins, matching the `head -1` the manifest job uses.
parse_compose() {
  awk '
    # Build helpers and shells, never shipped as a release component. Excluding
    # them is also what lets a pre-move compose file -- where every service tag
    # is a ${VAR} -- yield nothing, so the caller falls back to PROD_FILE.
    BEGIN { skip["ALPINE"]; skip["AWS_CLI"]; skip["AUTOHEAL"] }
    /^[[:space:]]*image:[[:space:]]*[^[:space:]#]+/ {
      sub(/^[[:space:]]*image:[[:space:]]*/, "")
      ref = $1
      # A ref holding a shell variable is the pre-move layout. Test the whole
      # ref, not just the tag: ${VAR:-default} contains its own colon, so a
      # last-colon split yields tag="-default}" and would slip past the guard.
      if (ref ~ /\$/) next
      if (ref ~ /@/) next                  # digest pin, no version to report
      p = 0
      for (i = length(ref); i > 0; i--) if (substr(ref, i, 1) == ":") { p = i; break }
      if (p == 0) next                     # no tag at all
      tag = substr(ref, p + 1)
      n = split(substr(ref, 1, p - 1), seg, "/")
      name = toupper(seg[n]); gsub(/-/, "_", name)
      if (name in skip) next
      if (name == "STARGATE_OPS") name = "OPS_AGENT"   # manifest key differs
      if (!(name in value)) { order[++k] = name; value[name] = tag }
    }
    END { for (i = 1; i <= k; i++) printf "%s\t%s\n", order[i], value[order[i]] }
  '
}

parse_versions() {   # stdin = customer-config -> "NAME<TAB>VERSION" (pre-move tags)
  awk '
    /^[A-Z][A-Z0-9_]*_VERSION=/ {
      eq = index($0, "=")
      name = substr($0, 1, eq - 1)
      val = substr($0, eq + 1)
      sub(/^"/, "", val)
      sub(/".*$/, "", val)
      sub(/_VERSION$/, "", name)
      if (!(name in value)) order[++n] = name
      value[name] = val
    }
    END { for (i = 1; i <= n; i++) printf "%s\t%s\n", order[i], value[order[i]] }
  '
}

versions_for_ref() {   # $1=git ref -> "NAME<TAB>VERSION" for what that tag ships
  local ref="$1" out
  out="$(git show "${ref}:${COMPOSE_FILE}" 2>/dev/null | parse_compose || true)"
  if [ -n "$out" ]; then
    printf '%s\n' "$out"
    return 0
  fi
  git show "${ref}:${PROD_FILE}" 2>/dev/null | parse_versions || true
}

TMP_PROD="$(mktemp)"
TMP_PREV=""
trap 'rm -f "$TMP_PROD" "$TMP_PREV"' EXIT

versions_for_ref "$TAG" > "$TMP_PROD" || true

echo "## Stargate release ${TAG}"
echo
echo "Tagged at \`${SHORT_SHA}\` — ${SUBJECT}"
echo
if [ -n "${CI_PIPELINE_URL:-}" ]; then
  echo "[Build pipeline](${CI_PIPELINE_URL})"
  echo
fi
echo "### Service versions"
echo
echo "| Service | Version | Release |"
echo "|---------|---------|---------|"
while IFS=$'\t' read -r svc ver; do
  [ -n "$svc" ] || continue
  printf '| %s | %s | %s |\n' "$svc" "$ver" "$(release_link "$svc" "$ver")"
done < "$TMP_PROD"
echo

if [ -n "$PREV_TAG" ]; then
  TMP_PREV="$(mktemp)"
  versions_for_ref "$PREV_TAG" > "$TMP_PREV" || true
  echo "### Service releases changed since ${PREV_TAG}"
  echo
  seen=""
  changed=0
  while IFS=$'\t' read -r svc ver; do
    repo="$(service_repo "$svc")"; [ -n "$repo" ] || continue
    prev="$(awk -F'\t' -v k="$svc" '$1==k{print $2}' "$TMP_PREV")"
    [ "$ver" != "$prev" ] || continue
    key="${repo}:${ver}"
    case " $seen " in *" $key "*) continue ;; esac
    seen="$seen $key"
    if is_semver "$ver"; then
      link=" ([release](${SVC_BASE}/${repo}/-/releases/${ver}))"
    else
      link=""
    fi
    printf -- '- %s %s → **%s**%s\n' "$svc" "${prev:-(new)}" "$ver" "$link"
    changed=1
  done < "$TMP_PROD"
  [ "$changed" -eq 1 ] || echo "_No first-party service version changes._"
  echo
fi
if [ -n "$PREV_TAG" ]; then
  echo "### Changes since ${PREV_TAG}"
else
  echo "### Changes"
fi
echo
CHANGES="$(git log "$RANGE" --no-merges --pretty='- %s (%an)' \
  | grep -v 'Automatic VM Images links update' || true)"
if [ -n "$CHANGES" ]; then
  echo "$CHANGES"
else
  echo "_No code changes._"
fi
