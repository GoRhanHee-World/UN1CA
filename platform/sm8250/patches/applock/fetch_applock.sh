#!/usr/bin/env bash
# Fetch Samsung AppLock and its privileged permission allowlist.
# An optional first argument supplies a local APK instead of downloading it.
set -euo pipefail

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)
MOD="$REPO/platform/sm8250/patches/applock/files/system"
BASE="https://raw.githubusercontent.com/AstroByteX-Code/ProjectArcadeX-SM8250/sixteen-qpr2/blobs/e1q/system/system"

APK_DEST="$MOD/priv-app/AppLock/AppLock.apk"
APK_URL="$BASE/priv-app/AppLock/AppLock.apk"

XML_NAME=privapp-permissions-com.samsung.android.applock.xml
XML_DEST="$MOD/etc/permissions/$XML_NAME"
XML_URL="$BASE/etc/permissions/$XML_NAME"

get() { # <dest> <url> [local-source]
    local dest=$1 url=$2 src=${3:-} tmp
    if [ -s "$dest" ] && [ -z "$src" ]; then
        echo "already present: ${dest//$REPO\//}"
        return 0
    fi
    tmp=$(mktemp)
    # shellcheck disable=SC2064
    trap "rm -f '$tmp'" EXIT
    if [ -n "$src" ]; then
        echo "copying $src"
        cp -f "$src" "$tmp"
    else
        echo "downloading $url"
        curl -fLSs -o "$tmp" "$url" || { echo "download failed"; exit 1; }
    fi
    [ -s "$tmp" ] || { echo "Empty file: $(basename "$dest")" >&2; exit 1; }
    mkdir -p "$(dirname "$dest")"
    mv -f "$tmp" "$dest"
    trap - EXIT
    echo "wrote ${dest//$REPO\//}"
}

get "$APK_DEST" "$APK_URL" "${1:-}"
get "$XML_DEST" "$XML_URL"
