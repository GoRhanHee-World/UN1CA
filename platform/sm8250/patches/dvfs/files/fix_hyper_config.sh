#!/bin/bash
# Copyright (c) 2026 GoRhanHee
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail

for config_path in "$@"; do
    config_tmp="$(mktemp "${config_path}.XXXXXX")"
    trap 'rm -f "$config_tmp"' EXIT
    jq -e '
        # This kernel exposes no core_ctl interface on any CPU cluster.
        # Remove the requests as well as their definitions; frequency boosts
        # and the other resources in each hint continue to work.
        (["CoreNumLittleMin", "CoreNumLittleMax", "CoreNumBigMin",
         "CoreNumBigMax", "CoreNumPrimeMin", "CoreNumPrimeMax",
         "CoreNumMin", "CoreNumMax"]
        + [.Resources[]? | select(.BoostPath == "/sys/kernel/mm/vmscan/am_app_launch") | .Name])
        as $unsupported
        | .Resources |= map(select(.Name as $name | $unsupported | index($name) | not))
        | if has("Hints") then
            .Hints |= map(if has("ResoureList") then
                .ResoureList |= map(select(.Resource as $name | $unsupported | index($name) | not))
                else . end)
          else . end
        # A combined rate limit cannot represent a down-only request without
        # also changing ramp-up behavior.
        | if has("Sysfs") then
            .Sysfs |= map(select((.Path // "" | endswith("/schedutil/down_rate_limit_us")) | not))
          else . end
    ' "$config_path" > "$config_tmp"
    chmod --reference="$config_path" "$config_tmp"
    mv -f "$config_tmp" "$config_path"
    trap - EXIT
done
