#!/usr/bin/env bash
# Generate release notes for a stargate-deployment release.

set -euo pipefail

TAG="${1:?usage: generate-release-notes.sh <tag>}"

PROD_FILE="docker-compose/customer-config-prod.example.sh"
PREPROD_FILE="docker-compose/customer-config-preprod.example.sh"

SEMVER_RE='^v[0-9]+\.[0-9]+\.[0-9]+$'              # v1.0.0 (manual milestones)


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

TMP_PROD="$(mktemp)"
TMP_PREPROD="$(mktemp)"
trap 'rm -f "$TMP_PROD" "$TMP_PREPROD"' EXIT

git show "${REF}:${PROD_FILE}" 2>/dev/null | parse_versions > "$TMP_PROD" || true
git show "${REF}:${PREPROD_FILE}" 2>/dev/null | parse_versions > "$TMP_PREPROD" || true

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
echo "| Service | Prod | Preprod |"
echo "|---------|------|---------|"
# Merge the two key/value lists; prod file defines the row order,
# preprod-only keys are appended.
awk -F'\t' '
  NR == FNR { if (!($1 in seen)) { order[++n] = $1; seen[$1] = 1 }; prod[$1] = $2; next }
            { if (!($1 in seen)) { order[++n] = $1; seen[$1] = 1 }; preprod[$1] = $2 }
  END {
    for (i = 1; i <= n; i++) {
      k = order[i]
      printf "| %s | %s | %s |\n", k, (k in prod ? prod[k] : "—"), (k in preprod ? preprod[k] : "—")
    }
  }
' "$TMP_PROD" "$TMP_PREPROD"
echo
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