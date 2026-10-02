#!/bin/bash

stalwart_listening() {
  local hexport tables
  hexport=$(printf ':%04X' "$1")
  tables=$(docker exec stargate-stalwart sh -c 'cat /proc/net/tcp /proc/net/tcp6 2>/dev/null; true' 2>/dev/null) || return 1
  awk -v p="$hexport" '$4 == "0A" && toupper($2) ~ (p "$") { found = 1 } END { exit !found }' <<< "$tables"
}
