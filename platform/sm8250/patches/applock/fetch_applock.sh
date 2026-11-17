#!/usr/bin/env bash
# Put Samsung's AppLock app and its privapp-permissions file where the minsos_applock mod expects
# them, and refuse anything that is not byte-for-byte the pair that was verified by hand.
#
#   tools/fetch_applock.sh                    # download both
#   tools/fetch_applock.sh /path/to/AppLock.apk   # use a local APK, still hash-gated
#
# Neither file is in git: .gitignore keeps borrowed Samsung binaries out of this repo (copyright,
# and in this case 3.6 MB), the same rule the KernelSU manager APK lives under. The mod ABORTs the
# build if they are missing, so a clean clone fails loudly here rather than shipping a ROM whose
# AppLock entry is dead again.
#
# WHY THE HASH GATE IS NOT PARANOIA ABOUT THE NETWORK.
#   The APK: AppLock reads and writes the lock state in system_server's own SharedPreferences and
#   is reached through 24 CHECK_APPLOCK_* intents hardcoded to its package name. Only a
#   Samsung-signed build is that app to the platform; a resigned one installs and does nothing.
#   The xml: it is a grant list read under ro.control_privapp_permissions=enforce. A wrong or
#   hand-edited one does not misbehave at runtime, it takes PackageManager down at boot.
# The URL is a branch, so upstream can move it under us. That is exactly what these hashes are for.
set -euo pipefail

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)
MOD="$REPO/platform/sm8250/patches/applock/files/system"
BASE="https://raw.githubusercontent.com/AstroByteX-Code/ProjectArcadeX-SM8250/sixteen-qpr2/blobs/e1q/system/system"

APK_DEST="$MOD/priv-app/AppLock/AppLock.apk"
APK_URL="$BASE/priv-app/AppLock/AppLock.apk"
APK_SIZE=3790177
APK_SHA=c920a9e9c92b07de158f224c13300b897d52f82addf2408936f168a26f4b8fa9

XML_NAME=privapp-permissions-com.samsung.android.applock.xml
XML_DEST="$MOD/etc/permissions/$XML_NAME"
XML_URL="$BASE/etc/permissions/$XML_NAME"
XML_SIZE=879
XML_SHA=057bab82ff448848663be9411570fc01f10b2a04d0a8855e2b51f49e404bb199

check() { # <file> <size> <sha256>
    local f=$1 want_size=$2 want_sha=$3 sz got
    [ -f "$f" ] || return 1
    sz=$(stat -c%s "$f")
    [ "$sz" = "$want_size" ] || { echo "  size $sz, want $want_size"; return 1; }
    got=$(sha256sum "$f" | cut -d' ' -f1)
    [ "$got" = "$want_sha" ] || { echo "  sha256 $got"; echo "     want $want_sha"; return 1; }
    return 0
}

get() { # <dest> <url> <size> <sha256> [local-source]
    local dest=$1 url=$2 size=$3 sha=$4 src=${5:-} tmp
    if check "$dest" "$size" "$sha" 2>/dev/null; then
        echo "already present and correct: ${dest//$REPO\//}"
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
    check "$tmp" "$size" "$sha" || { echo "REFUSING: that is not the pinned $(basename "$dest")"; exit 1; }
    mkdir -p "$(dirname "$dest")"
    mv -f "$tmp" "$dest"
    trap - EXIT
    echo "wrote ${dest//$REPO\//}"
}

get "$APK_DEST" "$APK_URL" "$APK_SIZE" "$APK_SHA" "${1:-}"
get "$XML_DEST" "$XML_URL" "$XML_SIZE" "$XML_SHA"

# Independent second opinion on the APK: the signing certificate and the package identity, not just
# the file hash. A correct file hash with the wrong certificate is impossible - this is the check
# that still means something on the day someone re-pins these hashes to a newer dump. A
# device-signed AppLock is the whole point: the lock state lives in system_server's own
# SharedPreferences, and a resigned build is a different app to the platform.
python3 "$REPO/platform/sm8250/patches/applock/apk_cert.py" "$APK_DEST" --expect-size 1240 \
    --expect-hash 34df0e7a9f1cf1892e45c056b4973cd81ccf148a4050d11aea4ac5a65f900a42 \
    || { echo "!! AppLock.apk is not signed by Samsung's platform certificate"; exit 1; }
echo "certificate and identity match: com.samsung.android.applock 3.0.0, CN=Samsung Cert"
