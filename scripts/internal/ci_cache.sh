#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Cache only host tools and original Odin packages, never patched ROM files.
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

firmware_group()
{
    local group=$1 primary=$2 extras=$3 spec model csc version folder key paths
    local -a specs extra_specs
    local manifest="$OUT_DIR/cache-metadata/$group.tsv"
    specs=("$primary")
    IFS=: read -r -a extra_specs <<< "$extras"
    specs+=("${extra_specs[@]}")
    : > "$manifest"
    for spec in "${specs[@]}"; do
        [ -n "$spec" ] || continue
        IFS=/ read -r model csc _ <<< "$spec"
        [[ "$model" =~ ^[A-Za-z0-9_-]+$ && "$csc" =~ ^[A-Za-z0-9]{3}$ ]] \
            || { echo 'Invalid firmware model/CSC' >&2; return 1; }
        folder="${model}_${csc}"
        [ -z "${seen[$folder]:-}" ] || continue
        version=$(GET_LATEST_FIRMWARE "$model" "$csc")
        [[ "$version" =~ ^[A-Za-z0-9._-]+/[A-Za-z0-9._/-]+$ ]] \
            || { echo "No valid firmware version for $folder" >&2; return 1; }
        seen[$folder]=1
        printf '%s\t%s\t%s\n' "$model" "$csc" "$version" >> "$manifest"
    done
    LC_ALL=C sort -o "$manifest" "$manifest"
    if [ ! -s "$manifest" ]; then
        cache_output "${group}_key" ''
        cache_output "${group}_paths" ''
        return 0
    fi
    key=$(sha256sum "$manifest" | cut -d ' ' -f 1)
    paths=$(awk -F '\t' -v base="$ODIN_DIR" '{print base "/" $1 "_" $2}' "$manifest")
    cache_output "${group}_key" "odin-v1-$key"
    cache_output "${group}_paths" "$paths"
}

firmware()
{
    # shellcheck source=/dev/null
    source "$SRC_DIR/scripts/utils/firmware_utils.sh"
    local -A seen=()
    mkdir -p "$OUT_DIR/cache-metadata"
    firmware_group source "$SOURCE_FIRMWARE" "${SOURCE_EXTRA_FIRMWARES:-}"
    firmware_group target "$TARGET_FIRMWARE" "${TARGET_EXTRA_FIRMWARES:-}"
    cat "$OUT_DIR/cache-metadata/source.tsv" "$OUT_DIR/cache-metadata/target.tsv" \
        > "$OUT_DIR/cache-metadata/firmware.tsv"
    printf 'FIRMWARE_VERSION_MANIFEST=%s\n' "$OUT_DIR/cache-metadata/firmware.tsv" >> "$GITHUB_ENV"
}

verify_firmware()
{
    local model csc version folder
    while IFS=$'\t' read -r model csc version; do
        folder="$ODIN_DIR/${model}_${csc}"
        [ "$(cat "$folder/.downloaded" 2>/dev/null)" = "$version" ] \
            || { echo "Firmware version mismatch for ${model}_${csc}" >&2; return 1; }
        # These are the original, checksum-verified packages used by extract_fw.
        if ! compgen -G "$folder/AP_*.md5" > /dev/null \
                || ! compgen -G "$folder/BL_*.md5" > /dev/null; then
            echo "Incomplete Odin packages for ${model}_${csc}" >&2
            return 1
        fi
    done < "$FIRMWARE_VERSION_MANIFEST"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    if [ "${1:-}" = tools ]; then
        tools
    elif [ "${1:-}" = firmware ]; then
        firmware
    elif [ "${1:-}" = verify-firmware ]; then
        verify_firmware
    else
        echo "Usage: $0 <tools|firmware|verify-firmware>" >&2
        exit 1
    fi
fi
