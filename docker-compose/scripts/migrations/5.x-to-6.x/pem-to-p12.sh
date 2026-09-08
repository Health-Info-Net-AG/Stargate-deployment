#!/bin/bash
set -eo pipefail

# Usage: pem-to-p12.sh [PEM_FILE ...] [--out FILE] [--password PASS] [--name NAME]
#   PEM_FILE ...    One or more PEM files that together contain a certificate
#                   and its private key (a combined file, or cert and key as
#                   separate files in any order). When no files are given, the
#                   PEM content is read from stdin -- paste it into the
#                   terminal and finish with Ctrl-D, or pipe it in.
#   --out FILE      Output .p12 path. Default: <certificate CN>.p12 in the
#                   current directory.
#   --password PASS Password protecting the .p12. Prompted for interactively
#                   when omitted.
#   --name NAME     Friendly name stored in the .p12. Default: certificate CN.
#
# Standalone companion to export-smime-keys.sh for machines the exported files
# cannot be copied to via scp: display the PEM files on the VM (cat), copy the
# text, then run this script locally and paste. The resulting .p12 imports
# into the dashboard's domain form and into mail clients. Requires openssl.
#
# Examples:
#   pem-to-p12.sh                                  # paste PEM, Ctrl-D
#   pem-to-p12.sh example.com.cert.pem example.com.key.pem
#   cat cert.pem key.pem | pem-to-p12.sh --out example.com.p12

PEM_FILES=()
OUT_FILE=""
PASSWORD=""
PASSWORD_SET=0
NAME=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --out)
      OUT_FILE="${2:-}"
      shift 2
      ;;
    --password)
      PASSWORD="${2:-}"
      PASSWORD_SET=1
      shift 2
      ;;
    --name)
      NAME="${2:-}"
      shift 2
      ;;
    -*)
      echo "Unknown option: $1"
      echo "Usage: $0 [PEM_FILE ...] [--out FILE] [--password PASS] [--name NAME]"
      exit 1
      ;;
    *)
      PEM_FILES+=("$1")
      shift
      ;;
  esac
done

if ! command -v openssl >/dev/null 2>&1; then
  echo "ERROR: openssl is required but not installed."
  exit 1
fi

# Collect the PEM content: concatenate the given files, or read stdin.
# openssl pkcs12 -export picks the private key and certificate(s) out of the
# combined input itself, so the order of blocks does not matter.
if [ "${#PEM_FILES[@]}" -gt 0 ]; then
  PEM=""
  for f in "${PEM_FILES[@]}"; do
    if [ ! -f "$f" ]; then
      echo "ERROR: file not found: $f"
      exit 1
    fi
    PEM+="$(cat "$f")"$'\n'
  done
else
  if [ -t 0 ]; then
    echo "Paste the PEM certificate and private key below."
    echo "Finish with Ctrl-D on an empty line:"
    echo ""
  fi
  PEM=$(cat)
fi

if ! grep -q -- "-----BEGIN CERTIFICATE-----" <<< "$PEM"; then
  echo "ERROR: input contains no certificate (missing BEGIN CERTIFICATE block)."
  exit 1
fi
if ! grep -qE -- "-----BEGIN (RSA |EC )?PRIVATE KEY-----" <<< "$PEM"; then
  echo "ERROR: input contains no private key (missing BEGIN PRIVATE KEY block)."
  exit 1
fi

# Reorder to key first, then certificate(s): openssl pkcs12 -export reading
# combined PEM from stdin only finds the key when it precedes the certs. This
# also drops any stray text pasted around the PEM blocks.
PEM=$(awk '
  /-----BEGIN (RSA |EC )?PRIVATE KEY-----/ {inkey=1}
  inkey {key = key $0 "\n"}
  /-----END (RSA |EC )?PRIVATE KEY-----/ {inkey=0}
  /-----BEGIN CERTIFICATE-----/ {incert=1}
  incert {certs = certs $0 "\n"}
  /-----END CERTIFICATE-----/ {incert=0}
  END {printf "%s%s", key, certs}
' <<< "$PEM")

# CN of the (first) certificate: default for the output filename and the
# friendly name inside the .p12.
CN=$(openssl x509 -noout -subject -nameopt multiline <<< "$PEM" 2>/dev/null \
  | awk -F'= ' '/commonName/ {print $2; exit}')
NAME="${NAME:-${CN:-smime}}"
OUT_FILE="${OUT_FILE:-${CN:-certificate}.p12}"

if [ -e "$OUT_FILE" ]; then
  echo "ERROR: $OUT_FILE already exists -- refusing to overwrite."
  exit 1
fi

if [ "$PASSWORD_SET" -eq 0 ]; then
  if [ ! -t 0 ] && [ ! -t 1 ]; then
    echo "ERROR: no --password given and no terminal to prompt on."
    exit 1
  fi
  # Prompt on /dev/tty: stdin may already be consumed by the PEM paste/pipe.
  read -r -s -p "PKCS#12 password: " PASSWORD < /dev/tty; echo
  read -r -s -p "Confirm password: " PASSWORD_CONFIRM < /dev/tty; echo
  if [ "$PASSWORD" != "$PASSWORD_CONFIRM" ]; then
    echo "ERROR: passwords do not match."
    exit 1
  fi
fi

# The .p12 holds the private key -- owner-only from the start. The password
# travels via environment, not argv, to keep it out of `ps`.
umask 077
if ! P12_PASSWORD="$PASSWORD" openssl pkcs12 -export \
    -name "$NAME" -passout env:P12_PASSWORD -out "$OUT_FILE" <<< "$PEM"; then
  rm -f "$OUT_FILE"
  echo "ERROR: PKCS#12 conversion failed. Check that the certificate and"
  echo "private key match and the PEM blocks are complete."
  exit 1
fi

echo ""
echo "  ✓ $OUT_FILE"
openssl x509 -noout -subject -enddate <<< "$PEM" 2>/dev/null | sed 's/^/    /'
echo ""
echo "  Import it in the dashboard's domain form (or a mail client)"
echo "  using the password you just set."
