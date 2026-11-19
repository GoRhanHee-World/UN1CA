#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Cache original build inputs and host tools, never patched ROM files.
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
                clang lld make libc6 libstdc++6 libbrotli-dev libbz2-dev \
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

prebuilts()
{
    local key
    local -a paths
    mapfile -t paths < "$SRC_DIR/.github/prebuilt-paths"
    # Tree IDs cover file contents, executable bits and symlinks without
    # fetching the large blobs from a partial clone.
    key=$(git -C "$SRC_DIR" ls-tree HEAD -- "${paths[@]}" | sha256sum | cut -d ' ' -f 1)
    cache_output prebuilts_key "prebuilts-v1-$key"
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

firmware()
{
    local model csc _identity version recipe prefix key previous
    IFS='/' read -r model csc _identity <<< "$1"
    version=$(cd "$OUT_DIR" && "$TOOLS_DIR/venv/bin/samloader" -m "$model" -r "$csc" checkupdate)
    # Samloader can print an error and exit successfully when no version exists.
    if [[ ! "$version" =~ ^[A-Z0-9]+(/[A-Z0-9]+){3}$ ]]; then
        echo "Could not determine the latest firmware for $model/$csc: $version" >&2
        return 1
    fi
    recipe=$(
        {
            sha256sum "$SRC_DIR/scripts/extract_fw.sh" \
                "$SRC_DIR/scripts/utils/firmware_utils.sh" \
                "$SRC_DIR/scripts/utils/build_utils.sh" \
                "$SRC_DIR/scripts/utils/common_utils.sh"
            git -C "$SRC_DIR" ls-tree -r HEAD -- external
        } | sha256sum | cut -d ' ' -f 1
    )
    prefix="firmware-v1-${model}_${csc}-"
    key="$prefix${version//\//_}-$recipe"
    mkdir -p "$OUT_DIR/cache/firmware/versions"
    printf '%s' "$version" > "$OUT_DIR/cache/firmware/versions/${model}_${csc}"
    printf 'FIRMWARE_VERSIONS_DIR=%s\n' "$OUT_DIR/cache/firmware/versions" >> "$GITHUB_ENV"
    previous="$OUT_DIR/cache/firmware/${model}_${csc}.previous"
    # Snapshot candidates before uploading, so parallel jobs cannot delete newer entries.
    gh api --method GET --paginate "repos/$GITHUB_REPOSITORY/actions/caches" \
        -f key="$prefix" -f ref="$GITHUB_REF" -F per_page=100 \
        --jq '.actions_caches[] | [.id, .key] | @tsv' > "$previous"
    echo "Latest firmware: $model/$csc $version"
    cache_output firmware_key "$key"
    cache_output firmware_path "$FW_DIR/${model}_${csc}"
    cache_output previous_caches "$previous"
}

prune_firmware()
{
    local key="$1" previous="$2" caches id old_key error
    # Cache save may only warn on upload errors; confirm the new entry exists first.
    caches=$(gh api --method GET "repos/$GITHUB_REPOSITORY/actions/caches" \
        -f key="$key" -f ref="$GITHUB_REF" --jq '.actions_caches[].key')
    if ! grep -Fxq "$key" <<< "$caches"; then
        echo "New firmware cache was not saved; keeping previous entries."
        return 0
    fi
    while IFS=$'\t' read -r id old_key; do
        if [ "$old_key" != "$key" ]; then
            # Another matrix job may already have removed this entry.
            if ! error=$(gh api --method DELETE "repos/$GITHUB_REPOSITORY/actions/caches/$id" 2>&1); then
                if [[ "$error" != *"(HTTP 404)"* ]]; then
                    echo "::warning::Could not remove previous firmware cache $id ($old_key): $error"
                fi
            fi
        fi
    done < "$previous"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    if [ "${1:-}" = tools ]; then
        tools
    elif [ "${1:-}" = prebuilts ]; then
        prebuilts
    elif [ "${1:-}" = wallpaper ]; then
        wallpaper
    elif [ "${1:-}" = firmware ]; then
        firmware "$2"
    elif [ "${1:-}" = prune-firmware ]; then
        prune_firmware "$2" "$3"
    else
        echo "Usage: $0 <tools|prebuilts|wallpaper|firmware FIRMWARE|prune-firmware KEY PREVIOUS>" >&2
        exit 1
    fi
fi
