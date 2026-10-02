#!/bin/bash
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INIT_VAULT="$here/../docker-compose/scripts/init-vault.sh"

eval "$(sed -n '/^policy_hcl() {/,/^}/p' "$INIT_VAULT")"

fail() { echo "FAIL: $*"; exit 1; }

wo=$(policy_hcl secret-mtaconf wo)
meta_rule=$(echo "$wo" | grep 'path "secret-mtaconf/metadata/stalwart/submission-password/\*"' || true)
data_rule=$(echo "$wo" | grep 'path "secret-mtaconf/data/stalwart/submission-password/\*"' || true)
blanket_rule=$(echo "$wo" | grep 'path "secret-mtaconf/data/\*"' || true)

[ -n "$meta_rule" ] || fail "no rule for the submission metadata path; deleting a password 403s"
case "$meta_rule" in
  *'"delete"'*) ;;
  *) fail "submission metadata cannot be deleted; a refused apply orphans the secret" ;;
esac
case "$data_rule" in
  *'"read"'*) ;;
  *) fail "submission data is unreadable; a failed rotate cannot be rolled back" ;;
esac
case "$blanket_rule" in
  *'"read"'*) fail "blanket read on data/* would expose every TLS private key" ;;
esac
case "$data_rule" in
  *'"delete"'*) fail "nothing deletes at the submission data path" ;;
esac
case "$meta_rule" in
  *'"list"'*) fail "nothing lists the submission metadata path" ;;
esac

relay_meta=$(echo "$wo" | grep 'path "secret-mtaconf/metadata/stalwart/relay-password/\*"' || true)
relay_data=$(echo "$wo" | grep 'path "secret-mtaconf/data/stalwart/relay-password/\*"' || true)

[ -n "$relay_meta" ] || fail "no rule for the relay metadata path; deleting a relay password 403s"
case "$relay_meta" in
  *'"delete"'*) ;;
  *) fail "relay metadata cannot be deleted" ;;
esac
case "$relay_meta" in
  *'"read"'*) fail "nothing reads relay password metadata" ;;
esac
[ -z "$relay_data" ] || fail "a narrower relay data rule would shadow the blanket write grant for no gain"

ro=$(policy_hcl secret-mailauth ro)
rw=$(policy_hcl secret-mtaconf rw)
case "$ro" in *'"read"'*) ;; *) fail "ro lost its read" ;; esac
case "$rw" in *'"delete"'*) ;; *) fail "rw lost its delete" ;; esac

mailauth_wo=$(policy_hcl secret-mailauth wo)
case "$mailauth_wo" in
  *stalwart/*) fail "the stalwart submission rules are granted on secret-mailauth too" ;;
esac
dashboard_wo=$(policy_hcl secret-mtaconf,secret-mailauth wo)
[ "$(echo "$dashboard_wo" | grep -c 'stalwart/')" = 3 ] || fail "the dashboard policy should carry exactly three stalwart rules"
echo "$dashboard_wo" | grep 'stalwart/' | grep -qv 'secret-mtaconf/' && fail "a stalwart rule is granted outside secret-mtaconf"

echo "PASS"
