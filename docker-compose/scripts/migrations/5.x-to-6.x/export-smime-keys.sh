#!/bin/bash
set -eo pipefail

# Usage: export-smime-keys.sh DOMAIN [--out DIR] [--password PASS]
#   DOMAIN          Domain whose S/MIME certificate(s) and private key(s) to
#                   export (e.g. example.com).
#   --out DIR       Output directory. Default: ./smime-export/DOMAIN
#   --password PASS Password protecting the .p12 file(s). Prompted for
#                   interactively when omitted.
#
# Exports each certificate/key pair of the domain from the smimekeys-client
# API as PEM (BASE.cert.pem + BASE.key.pem) and as PKCS#12 (BASE.p12), where
# BASE is the domain name (suffixed _2, _3, ... when the domain has more than
# one key pair). The .p12 bundles cert + key for import into mail clients
# (Outlook, Apple Mail, Thunderbird) and into the dashboard's domain form,
# whose upload accepts PKCS#12 only (parsed client-side with node-forge, which
# handles the OpenSSL 3 defaults used here but supports RSA keys only --
# matching what smimekeys generates for domains).

DOMAIN=""
OUT_DIR=""
PASSWORD=""
PASSWORD_SET=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --out)
      OUT_DIR="${2:-}"
      shift 2
      ;;
    --password)
      PASSWORD="${2:-}"
      PASSWORD_SET=1
      shift 2
      ;;
    -*)
      echo "Unknown option: $1"
      echo "Usage: $0 DOMAIN [--out DIR] [--password PASS]"
      exit 1
      ;;
    *)
      if [ -n "$DOMAIN" ]; then
        echo "Unexpected argument: $1"
        echo "Usage: $0 DOMAIN [--out DIR] [--password PASS]"
        exit 1
      fi
      DOMAIN="$1"
      shift
      ;;
  esac
done

if [ -z "$DOMAIN" ]; then
  echo "Usage: $0 DOMAIN [--out DIR] [--password PASS]"
  exit 1
fi

# The smimekeys-client API is unauthenticated and bound to loopback only
# (see the ports mapping in docker-compose.yml), so this must run on the host.
SMIMEKEYS_API="http://127.0.0.1:8081"

# Default next to wherever the script is run from: this migration script gets
# copied onto the old 5.x host, so it must not assume a repo layout around it.
OUT_DIR="${OUT_DIR:-$PWD/smime-export/$DOMAIN}"

echo "============================================"
echo "  S/MIME Certificate & Key Export"
echo "============================================"
echo ""
echo "Domain: $DOMAIN"
echo "Output directory: $OUT_DIR"
echo ""

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required but not installed."
  exit 1
fi

if ! docker ps --format '{{.Names}}' | grep -q "stargate-smimekeys-client"; then
  echo "ERROR: stargate-smimekeys-client container is not running."
  echo "Start the services first: ./scripts/start.sh"
  exit 1
fi

# openssl_pkcs12 reads a combined PEM (key + cert) on stdin and writes the
# PKCS#12 bundle to stdout. Prefers host openssl; falls back to the postgres
# container (Debian-based, ships openssl) so minimal hosts still work. The
# password travels via environment, not argv, to keep it out of `ps`.
if command -v openssl >/dev/null 2>&1; then
  openssl_pkcs12() {
    P12_PASSWORD="$PASSWORD" openssl pkcs12 -export \
      -name "$DOMAIN S/MIME" -passout env:P12_PASSWORD
  }
else
  echo "Note: openssl not found on host, using the postgres container's openssl."
  openssl_pkcs12() {
    docker exec -i -e P12_PASSWORD="$PASSWORD" stargate-postgres openssl pkcs12 -export \
      -name "$DOMAIN S/MIME" -passout env:P12_PASSWORD
  }
fi

echo "Fetching keys from smimekeys-client..."

# api_get URL -> sets HTTP_STATUS and BODY. curl -f would hide the status code
# needed to tell "endpoint missing" (old smimekeys image) apart from an API
# error, so capture it explicitly.
api_get() {
  local out
  if ! out=$(curl -s --max-time 30 -w '\n%{http_code}' "$1"); then
    echo "ERROR: cannot reach smimekeys-client at $SMIMEKEYS_API"
    exit 1
  fi
  HTTP_STATUS="${out##*$'\n'}"
  BODY="${out%$'\n'*}"
}

api_fail() {
  echo "ERROR: $1 (HTTP $HTTP_STATUS):"
  echo "$BODY" | jq -r '.message? // .error? // .' 2>/dev/null || echo "$BODY"
  exit 1
}

# The certificates listing carries everything but the private key; each key is
# fetched separately by the certificate's subject key ID. Root CA certificates
# are excluded: their private keys are not exportable.
api_get "$SMIMEKEYS_API/v1/certs?status=good&domain=$DOMAIN"
[ "$HTTP_STATUS" = "200" ] || api_fail "failed to fetch certificates for domain '$DOMAIN'"
CERTS=$(echo "$BODY" | jq '[.certificates[]? | select(.rootCA | not)]')

COUNT=$(echo "$CERTS" | jq 'length' 2>/dev/null || echo 0)
if [ -z "$COUNT" ] || [ "$COUNT" = "null" ] || [ "$COUNT" -eq 0 ]; then
  echo "ERROR: no certificates/keys found for domain '$DOMAIN'."
  exit 1
fi
echo "  ✓ Found $COUNT key pair(s)"
echo ""

if [ "$PASSWORD_SET" -eq 0 ]; then
  if [ ! -t 0 ]; then
    echo "ERROR: no --password given and no terminal to prompt on."
    exit 1
  fi
  read -r -s -p "PKCS#12 password: " PASSWORD; echo
  read -r -s -p "Confirm password: " PASSWORD_CONFIRM; echo
  if [ "$PASSWORD" != "$PASSWORD_CONFIRM" ]; then
    echo "ERROR: passwords do not match."
    exit 1
  fi
fi

# The exported files hold private keys in clear text -- owner-only from the start.
umask 077
mkdir -p "$OUT_DIR"

EXPORTED=0
for ((i = 0; i < COUNT; i++)); do
  CERT=$(echo "$CERTS" | jq -r ".[$i].certificate")
  SKID=$(echo "$CERTS" | jq -r ".[$i].subjectKeyId")
  USAGE=$(echo "$CERTS" | jq -r ".[$i].keyUsage")

  BASE="$DOMAIN"
  [ "$i" -gt 0 ] && BASE="${DOMAIN}_$((i + 1))"

  if [ -z "$CERT" ] || [ "$CERT" = "null" ]; then
    echo "  ✗ Entry $((i + 1)): no certificate, skipping"
    continue
  fi

  printf '%s\n' "$CERT" > "$OUT_DIR/$BASE.cert.pem"
  echo "  ✓ $BASE.cert.pem (keyUsage: $USAGE)"

  api_get "$SMIMEKEYS_API/v1/keys/$SKID?privateKey"
  [ "$HTTP_STATUS" = "200" ] || api_fail "failed to fetch private key $SKID"
  KEY=$(echo "$BODY" | jq -r '.privateKeyPEM // empty')

  if [ -z "$KEY" ] || [ "$KEY" = "null" ]; then
    echo "  ✗ Entry $((i + 1)): private key not exportable, skipping key and .p12"
    continue
  fi

  printf '%s\n' "$KEY" > "$OUT_DIR/$BASE.key.pem"
  echo "  ✓ $BASE.key.pem"

  if printf '%s\n%s\n' "$KEY" "$CERT" | openssl_pkcs12 > "$OUT_DIR/$BASE.p12"; then
    echo "  ✓ $BASE.p12"
    ((EXPORTED++)) || true
  else
    rm -f "$OUT_DIR/$BASE.p12"
    echo "  ✗ Entry $((i + 1)): PKCS#12 conversion failed"
    exit 1
  fi
done

echo ""
echo "============================================"
echo "  Export Complete"
echo "============================================"
echo ""
echo "  $EXPORTED key pair(s) exported to: $OUT_DIR"
echo ""
echo "  Files contain private keys -- handle with care and"
echo "  delete them once imported where needed."
echo ""
