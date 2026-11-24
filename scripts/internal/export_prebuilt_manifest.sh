#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Export an explicit blob manifest from an already extracted Samsung firmware.
set -euo pipefail

firmware="$(realpath "$1")"
prebuilts="$(realpath "$2")"
manifest="$prebuilts/files.list"
system_root="$firmware/system/system"
[[ -d "$system_root" ]] || system_root="$firmware/system"
if [[ -f "$prebuilts/required-sdk" ]] &&
        ! grep -qxF "ro.build.version.sdk=$(cat "$prebuilts/required-sdk")" "$system_root/build.prop"; then
    echo "Snapshot requires Android SDK $(cat "$prebuilts/required-sdk")" >&2
    exit 1
fi

staging="$(mktemp -d "${prebuilts}.export.XXXXXX")"
trap 'rm -rf "$staging"' EXIT
declare -A partitions=()
while IFS= read -r entry || [[ -n "$entry" ]]; do
    [[ -n "$entry" && "$entry" != \#* ]] || continue
    case "$entry" in
        system/*) pattern="$system_root/${entry#system/}" ;;
        vendor/*|product/*|system_ext/*) pattern="$firmware/$entry" ;;
        *) echo "Unsupported manifest entry: $entry" >&2; exit 1 ;;
    esac
    mapfile -t matches < <(compgen -G "$pattern" | LC_ALL=C sort)
    if [[ "${#matches[@]}" != 1 ]]; then
        echo "Expected one match for $entry, found ${#matches[@]}" >&2
        exit 1
    fi
    source_path="${matches[0]%/}"
    if [[ "$entry" == system/* ]]; then
        relative="system/${source_path#"$system_root"/}"
    else
        relative="${source_path#"$firmware"/}"
    fi
    partitions["${entry%%/*}"]=1
    mkdir -p "$staging/${relative%/*}"
    cp -a "$source_path" "$staging/$relative"
done < "$manifest"

# Preserve the source ownership/SELinux metadata used by ADD_TO_WORK_DIR.
partition_paths=()
for partition in "${!partitions[@]}"; do
    partition_paths+=("$staging/$partition")
    cp "$firmware/fs_config-$partition" "$staging/fs_config-$partition"
    cp "$firmware/file_context-$partition" "$staging/file_context-$partition"
done
cp "$firmware/.extracted" "$staging/.current"
while IFS= read -r -d '' file; do
    if [[ "$(stat -c %s "$file")" -gt 52428800 ]]; then
        split -d -b 52428800 "$file" "$file."
        rm "$file"
    fi
done < <(find "${partition_paths[@]}" -type f -print0)
# Keep the recipe, but remove files no longer present in the refreshed snapshot.
find "$prebuilts" -mindepth 1 -maxdepth 1 ! -name files.list ! -name required-sdk -exec rm -rf -- {} +
cp -a "$staging/." "$prebuilts/"
