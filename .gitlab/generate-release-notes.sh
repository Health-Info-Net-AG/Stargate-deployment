#!/usr/bin/env bash
# Generate release notes for a stargate-deployment release.

set -euo pipefail

TAG="${1:?usage: generate-release-notes.sh <tag>}"

# Image versions moved out of customer-config and into docker-compose.yml, so the
# release manifest built by the `generate_manifest` CI job is now the source for
# this table. It is present in the release job's workspace as an artifact; the
# manifest for a *previous* tag is read from origin/main:manifests/<tag>.json.
# PROD_FILE remains the fallback for tags cut before that move, whose
# customer-config-prod.example.sh still carries the *_VERSION pins.
MANIFEST_FILE="${MANIFEST_FILE:-manifest.json}"
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

is_semver() { printf '%s' "$1" | grep -Eq '^v[0-9]+\.[0-9]+\.[0-9]+$'; }

release_link() {   # $1=NAME $2=VERSION -> markdown cell
  local repo; repo="$(service_repo "$1")"
  if [ -n "$repo" ] && is_semver "$2"; then
    printf '[notes](%s/%s/-/releases/%s)' "$SVC_BASE" "$repo" "$2"
  else
    printf '—'
  fi
}


prev_tag() {
  git tag --merged "$1" --sort=-v:refname 2>/dev/null \
    | grep -E "$2" | grep -Fvx "$TAG" | head -n1 || true
}

REF="$TAG"
HEADER="Stargate release ${TAG}"
ORIGIN_WORD="Tagged at"
# Roll up since the previous semver tag.
PREV_TAG="$(prev_tag "$REF" "$SEMVER_RE")"

if [ -n "$PREV_TAG" ]; then
  RANGE="${PREV_TAG}..${REF}"
else
  RANGE="$REF" # no previous tag -> all history
fi

SHORT_SHA="$(git rev-parse --short "$REF")"
SUBJECT="$(git log -1 --pretty=%s "$REF")"


parse_versions() {
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

# parse_manifest: stdin = release manifest JSON -> "NAME<TAB>VERSION" lines,
# matching parse_versions' output so both sources are interchangeable.
parse_manifest() {
  jq -r '.images | to_entries[] | "\(.key | sub("_VERSION$"; ""))\t\(.value)"'
}

# versions_for_ref REF -> "NAME<TAB>VERSION" for a tag other than the one being
# released: its merged manifest if there is one, else its customer-config pins.
versions_for_ref() {
  local ref="$1"
  if git cat-file -e "origin/main:manifests/${ref}.json" 2>/dev/null &&
     git show "origin/main:manifests/${ref}.json" | parse_manifest 2>/dev/null; then
    return 0
  fi
  git show "${ref}:${PROD_FILE}" 2>/dev/null | parse_versions || true
}

TMP_PROD="$(mktemp)"
TMP_PREV=""
trap 'rm -f "$TMP_PROD" "$TMP_PREV"' EXIT

# The tag being released: its manifest is not on main yet (CI opens an MR for it
# after the release), so use the artifact from the generate_manifest job.
if [ -f "$MANIFEST_FILE" ]; then
  parse_manifest < "$MANIFEST_FILE" > "$TMP_PROD" || true
fi
if [ ! -s "$TMP_PROD" ]; then
  versions_for_ref "$REF" > "$TMP_PROD" || true
fi

echo "## ${HEADER}"
echo
echo "${ORIGIN_WORD} \`${SHORT_SHA}\` — ${SUBJECT}"
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