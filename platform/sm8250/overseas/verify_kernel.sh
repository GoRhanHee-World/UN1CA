#!/usr/bin/env bash
set -euo pipefail

[ "$#" = 2 ] || { echo "Usage: $0 <kernel.zip> <x1q|y2q|z3q>" >&2; exit 1; }
payload=$1
device=$2
case "$device" in x1q|y2q|z3q) ;; *) echo "Unsupported S20 target: $device" >&2; exit 1 ;; esac
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
unzip -p "$payload" s20-overseas.json > "$tmp/info.json"
jq -e --arg device "$device" '
    .schema == 1 and .device == $device and
    (.board_ids | type == "array" and length > 0 and length == (unique | length)) and
    (.board_ids | index(13) != null and index(14) != null) and
    (if .device == "y2q" then (.board_ids | index(15) != null) else true end) and
    (if .device == "z3q" then true else .samsung_nfc == true end)
' "$tmp/info.json" > /dev/null || { echo "Missing or incompatible overseas kernel metadata" >&2; exit 1; }
for part in Image dtb dtbo.img; do
    unzip -p "$payload" "$part" > "$tmp/$part"
    [ -s "$tmp/$part" ] || { echo "Empty kernel payload: $part" >&2; exit 1; }
done
