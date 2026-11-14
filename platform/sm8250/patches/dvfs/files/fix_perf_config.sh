#!/bin/bash
# Copyright (c) 2026 GoRhanHee
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail

perf_dir="$1"
config_path="$perf_dir/perfboostsconfig.xml"
if [ -f "$config_path" ]; then
    config_tmp="$(mktemp "${config_path}.XXXXXX")"
    trap 'rm -f "$config_tmp"' EXIT
    # Qualcomm scroll boosts can bypass Hyper and send the same unsupported
    # hotplug opcodes directly. Remove only those opcode/value pairs.
    awk '
        BEGIN { RS = "\0"; ORS = "" }
        {
            remaining = $0
            while (match(remaining, /Resources="[^"]*"/)) {
                prefix = substr(remaining, 1, RSTART - 1)
                body = substr(remaining, RSTART + 11, RLENGTH - 12)
                remaining = substr(remaining, RSTART + RLENGTH)
                count = split(body, values, ",")
                if (count % 2 != 0) {
                    print "Invalid perf resource opcode/value list\n" > "/dev/stderr"
                    exit 1
                }
                result = ""
                separator = ""
                for (i = 1; i <= count; i += 2) {
                    opcode = toupper(values[i])
                    gsub(/[[:space:]]/, "", opcode)
                    if (opcode ~ /^0X4100[04][012]00$/) continue
                    result = result separator values[i] "," values[i + 1]
                    separator = ","
                }
                print prefix "Resources=\"" result "\""
            }
            print remaining
        }
    ' "$config_path" > "$config_tmp"
    chmod --reference="$config_path" "$config_tmp"
    mv -f "$config_tmp" "$config_path"
    trap - EXIT
fi

config_path="$perf_dir/commonresourceconfigs.xml"
if [ -f "$config_path" ]; then
    # Also declare the missing kernel facility unsupported for direct clients.
    sed -i -E '/Node="SPECIAL_NODE - lock_(min|max)_cores"/ {
        /Supported=/! s| */>| Supported="no" />|
        s/Supported="[^"]*"/Supported="no"/
    }' "$config_path"
fi
