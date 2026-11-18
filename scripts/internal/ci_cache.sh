#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Cache host tools and converted wallpapers, never firmware or patched ROM files.
set -euo pipefail

cache_output()
{
    printf '%s<<CACHE_OUTPUT\n%s\nCACHE_OUTPUT\n' "$1" "$2" >> "$GITHUB_OUTPUT"
}

tools()
{
    local environment sources
    environment=$(
        {
            uname -s -m
            cat /etc/os-release
            clang --version
            cmake --version
            java -version 2>&1
            python3 --version
            dpkg-query -W -f='${binary:Package}=${Version}\n' \
                clang lld cmake make libc6 libstdc++6 libbrotli-dev libbz2-dev \
                libgtest-dev libprotobuf-dev libunwind-dev libpcre2-dev \
                libzstd-dev protobuf-compiler
        } | sha256sum | cut -d ' ' -f 1
    )
    # Tree entries include submodule commits as well as our tool sources/patches.
    sources=$(
        {
            git -C "$SRC_DIR" ls-tree -r HEAD -- external
            sha256sum "$SRC_DIR/scripts/internal/prepare_gradle.sh" \
                "$SRC_DIR/scripts/utils/log_utils.sh" "${BASH_SOURCE[0]}"
            printf '%s\n' "$SRC_DIR"
        } | sha256sum | cut -d ' ' -f 1
    )
    cache_output tools_key "tools-v1-$environment-$sources"
    cache_output ccache_prefix "ccache-v1-$environment-"
}

wallpaper()
{
    local key
    key=$(
        {
            git -C "$SRC_DIR" ls-tree -r HEAD -- prebuilts/samsung/m3qksx/system/priv-app/wallpaper-res
            sha256sum "$SRC_DIR/unica/mods/wallpaper/customize.sh"
            ffmpeg -version
            cwebp -version
            printf '%s\n' "$TARGET_COMMON_SUPPORT_DYN_RESOLUTION_CONTROL" "$TARGET_PRODUCT_SHIPPING_API_LEVEL"
        } | sha256sum | cut -d ' ' -f 1
    )
    cache_output wallpaper_key "wallpaper-v1-$key"
    printf 'WALLPAPER_CACHE_DIR=%s\n' "$OUT_DIR/cache/wallpapers/$key" >> "$GITHUB_ENV"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    if [ "${1:-}" = tools ]; then
        tools
    elif [ "${1:-}" = wallpaper ]; then
        wallpaper
    else
        echo "Usage: $0 <tools|wallpaper>" >&2
        exit 1
    fi
fi
