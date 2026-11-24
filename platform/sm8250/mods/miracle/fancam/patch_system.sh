#!/usr/bin/env bash
# Copyright (c) 2026 ssch71, GoRhanHee
# SPDX-License-Identifier: GPL-3.0-or-later
# Apply the reference SM8250 patches without executing Python.
set -euo pipefail

spec="$1"
name="$2"
file="$3"
patched="$(mktemp "${file}.XXXXXX")"
trap 'rm -f "$patched"' EXIT
cp -p "$file" "$patched"
patches="$(jq -er --arg name "$name" '.[$name].patches[] | [.off, .old, .new] | @tsv' "$spec")"
while IFS=$'\t' read -r offset old new; do
    [[ "$offset" =~ ^[0-9]+$ && "$old" =~ ^([0-9a-f]{2})+$ && "$new" =~ ^([0-9a-f]{2})+$ ]]
    [[ "${#old}" == "${#new}" ]]
    found="$(dd if="$patched" bs=1 skip="$offset" count="$((${#old} / 2))" status=none | xxd -p -c 0)"
    [[ "$found" != "$new" ]] || continue
    if [[ "$found" != "$old" ]]; then
        echo "$name: byte mismatch at $offset" >&2
        exit 1
    fi
    printf '%s' "$new" | xxd -r -p | dd of="$patched" bs=1 seek="$offset" conv=notrunc status=none
done <<< "$patches"
mv "$patched" "$file"
echo "$name: patched"
