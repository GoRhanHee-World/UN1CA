# SPDX-License-Identifier: GPL-3.0-or-later
# shellcheck shell=bash

# Install a tracked system directory, joining large blobs split by blob-update CI.
ADD_PREBUILT_SYSTEM_TREE()
{
    local source="$1" tree="$2" root file relative
    root="$SRC_DIR/prebuilts/samsung/$source/system"
    if [ ! -d "$root/$tree" ]; then
        ABORT "Missing $source/$tree snapshot; run Update prebuilt blobs and import its result first"
        return 1
    fi
    while IFS= read -r -d '' file; do
        relative="${file#"$root"/}"
        case "$relative" in
            *.[0-9][0-9])
                [[ "$relative" == *.00 ]] || continue
                relative="${relative%.*}"
                ;;
        esac
        ADD_TO_WORK_DIR "$source" "system" "system/$relative" || return 1
    done < <(find "$root/$tree" \( -type f -o -type l \) -print0 | LC_ALL=C sort -z)
}
