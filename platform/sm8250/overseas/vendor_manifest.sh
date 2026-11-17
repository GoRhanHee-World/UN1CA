#!/usr/bin/env bash
set -euo pipefail

[ "$#" = 2 ] || { echo "Usage: $0 <radio|soter> <vendor-manifest.xml>" >&2; exit 1; }
manifest=$2
grep -q '<manifest .*type="device"' "$manifest" || { echo "Expected a vendor device manifest" >&2; exit 1; }

case "$1" in
    radio)
        # The shared UN1CA vendor already declares both SIM slots. Check the
        # fqnames in their HAL blocks instead of duplicating upstream's entries.
        awk '
            /<hal[ >]/ { package = "" }
            /<name>/ && package == "" {
                package = $0; sub(/^.*<name>/, "", package); sub(/<\/name>.*$/, "", package)
            }
            /<fqname>/ {
                value = $0; sub(/^.*<fqname>/, "", value); sub(/<\/fqname>.*$/, "", value)
                found[package "/" value]++
            }
            END {
                required[1] = "android.hardware.radio/@1.2::ISap/slot2"
                required[2] = "android.hardware.radio/@1.5::IRadio/slot2"
                required[3] = "vendor.samsung.hardware.radio/@2.2::ISehRadio/slot2"
                required[4] = "vendor.samsung.hardware.radio.bridge/@2.0::ISehBridge/slot2"
                required[5] = "vendor.samsung.hardware.radio.channel/@2.0::ISehChannel/epdgd2"
                required[6] = "vendor.samsung.hardware.radio.channel/@2.0::ISehChannel/imsd2"
                for (i = 1; i <= 6; i++) if (found[required[i]] != 1) {
                    print "Missing or duplicate dual-SIM entry: " required[i] > "/dev/stderr"; bad = 1
                }
                exit bad
            }
        ' "$manifest"
        ;;
    soter)
        if grep -q '<name>vendor.samsung.hardware.soter</name>' "$manifest"; then
            echo "Samsung Soter is already declared; recheck the vendor" >&2
            exit 1
        fi
        [ "$(grep -c '^[[:space:]]*</manifest>[[:space:]]*$' "$manifest")" = 1 ] \
            || { echo "Expected one vendor manifest closing tag" >&2; exit 1; }
        tmp=$(mktemp)
        trap 'rm -f "$tmp"' EXIT
        awk '
            /^[[:space:]]*<\/manifest>[[:space:]]*$/ {
                print "    <hal format=\"hidl\">"
                print "        <name>vendor.samsung.hardware.soter</name>"
                print "        <transport>hwbinder</transport>"
                print "        <version>3.0</version>"
                print "        <interface>"
                print "            <name>ISehSoter</name>"
                print "            <instance>default</instance>"
                print "        </interface>"
                print "        <fqname>@3.0::ISehSoter/default</fqname>"
                print "    </hal>"
            }
            { print }
        ' "$manifest" > "$tmp"
        cat "$tmp" > "$manifest"
        ;;
    *) echo "Unknown operation: $1" >&2; exit 1 ;;
esac
