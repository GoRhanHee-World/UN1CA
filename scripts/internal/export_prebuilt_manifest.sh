#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Export an explicit blob manifest from an already extracted Samsung firmware.
set -euo pipefail

firmware="$1"
prebuilts="$2"
manifest="$prebuilts/files.list"
system_root="$firmware/system/system"
[[ -d "$system_root" ]] || system_root="$firmware/system"
if ! grep -q '^ro.build.version.sdk=37$' "$system_root/build.prop"; then
    echo "The S23 compatibility snapshot requires Android 17 / One UI 9" >&2
    exit 1
fi

staging="$(mktemp -d "${prebuilts}.export.XXXXXX")"
trap 'rm -rf "$staging"' EXIT
while IFS= read -r entry || [[ -n "$entry" ]]; do
    [[ -n "$entry" && "$entry" != \#* ]] || continue
    case "$entry" in
        system/*) pattern="$system_root/${entry#system/}" ;;
        *) echo "Unsupported manifest entry: $entry" >&2; exit 1 ;;
    esac
    mapfile -t matches < <(compgen -G "$pattern" | LC_ALL=C sort)
    if [[ "${#matches[@]}" != 1 ]]; then
        echo "Expected one match for $entry, found ${#matches[@]}" >&2
        exit 1
    fi
    source_path="${matches[0]%/}"
    relative="system/${source_path#"$system_root"/}"
    mkdir -p "$staging/${relative%/*}"
    cp -a "$source_path" "$staging/$relative"
done < "$manifest"

# Preserve the source ownership/SELinux metadata used by ADD_TO_WORK_DIR.
cp "$firmware/fs_config-system" "$staging/fs_config-system"
cp "$firmware/file_context-system" "$staging/file_context-system"
cp "$firmware/.extracted" "$staging/.current"
sha256sum "$manifest" | cut -d ' ' -f 1 > "$staging/.manifest.sha256"
while IFS= read -r -d '' file; do
    if [[ "$(stat -c %s "$file")" -gt 52428800 ]]; then
        split -d -b 52428800 "$file" "$file."
        rm "$file"
    fi
done < <(find "$staging/system" -type f -print0)
(
    cd "$staging"
    find system -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum > SHA256SUMS
    sha256sum --quiet -c SHA256SUMS
)
# Keep the recipe, but remove files no longer present in the refreshed snapshot.
find "$prebuilts" -mindepth 1 -maxdepth 1 ! -name files.list -exec rm -rf -- {} +
cp -a "$staging/." "$prebuilts/"
