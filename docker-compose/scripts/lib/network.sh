#!/bin/bash

ipv4_to_int() {
  local a b c d octet
  IFS=. read -r a b c d <<< "$1" || return 1
  for octet in "$a" "$b" "$c" "$d"; do
    [[ "$octet" =~ ^[0-9]{1,3}$ ]] && (( 10#$octet <= 255 )) || return 1
  done
  echo $(( (10#$a << 24) | (10#$b << 16) | (10#$c << 8) | 10#$d ))
}

cidr_bounds() {
  local cidr="$1" ip len base mask
  ip="${cidr%/*}"
  if [ "$ip" = "$cidr" ]; then len=32; else len="${cidr#*/}"; fi
  [[ "$len" =~ ^[0-9]{1,2}$ ]] && (( 10#$len <= 32 )) || return 1
  base=$(ipv4_to_int "$ip") || return 1
  mask=$(( (0xFFFFFFFF << (32 - 10#$len)) & 0xFFFFFFFF ))
  echo "$(( base & mask )) $(( (base & mask) | (~mask & 0xFFFFFFFF) ))"
}

cidrs_overlap() {
  local a b
  a=$(cidr_bounds "$1") || return 2
  b=$(cidr_bounds "$2") || return 2
  (( ${a% *} <= ${b#* } && ${b% *} <= ${a#* } ))
}

host_routes_overlapping() {
  local subnet="$1" dst dev
  while read -r dst dev; do
    [ -n "$dst" ] && [ "$dst" != "default" ] || continue
    case "$dev" in br-*) continue ;; esac
    if cidrs_overlap "$subnet" "$dst"; then
      echo "$dst dev ${dev:-?}"
    fi
  done < <(ip -o -4 route show 2>/dev/null | awk '{
    dst = $1
    if (dst ~ /^(unicast|blackhole|unreachable|prohibit|throw|local|broadcast|multicast|anycast|nat)$/) dst = $2
    dev = ""
    for (i = 1; i < NF; i++) if ($i == "dev") dev = $(i + 1)
    print dst, dev
  }')
}

stalwart_listening() {
  local hexport tables
  hexport=$(printf ':%04X' "$1")
  tables=$(docker exec stargate-stalwart sh -c 'cat /proc/net/tcp /proc/net/tcp6 2>/dev/null; true' 2>/dev/null) || return 1
  awk -v p="$hexport" '$4 == "0A" && toupper($2) ~ (p "$") { found = 1 } END { exit !found }' <<< "$tables"
}
