# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later
# MinsOS I-167: preserve Surface::mGenerationNumber across disconnect/reconnect.
# https://gitlab.com/minsos1/MinsOS/-/commit/8ab358bbad71bcb34dc8d344ee61f74fa105f80b
# Android 17 clears the client generation while BufferQueue keeps its value;
# ACodec attaches buffers stamped 0 and the queue rejects them. NOP the reset.

_PATCH_SURFACE_GENERATION()
{
    local LIB="$1" BEFORE="$2" AFTER="$3" ELF="$4"
    local FILE="$WORK_DIR/system/system/$LIB/libgui.so" DATA OLD_COUNT NEW_COUNT
    [[ "$LIB" != lib || -f "$FILE" ]] || return 0
    [[ "$(xxd -p -l 7 "$FILE")" == "$ELF" ]] || {
        ABORT "Unexpected ELF: $FILE"; return 1;
    }
    DATA="$(xxd -p -c 0 "$FILE")"
    OLD_COUNT="$( { grep -o "$BEFORE" <<< "$DATA" || true; } | wc -l)"
    NEW_COUNT="$( { grep -o "$AFTER" <<< "$DATA" || true; } | wc -l)"
    if [[ "$OLD_COUNT" == 0 && "$NEW_COUNT" == 1 ]]; then
        return 0
    fi
    [[ "$OLD_COUNT" == 1 && "$NEW_COUNT" == 0 ]] || {
        ABORT "Unknown Surface::disconnect instructions: $FILE"; return 1;
    }
    # First pass validates both libraries before either is modified.
    [[ "$_SURFACE_CHECK_ONLY" == 0 ]] || return 0
    HEX_PATCH "$FILE" "$BEFORE" "$AFTER" || return 1
    LOG "- $LIB/libgui.so preserves Surface generation"
}

for _SURFACE_CHECK_ONLY in 1 0; do
    _PATCH_SURFACE_GENERATION lib64 7f6a03b968b20d39 1f2003d568b20d39 7f454c46020101 || return 1
    _PATCH_SURFACE_GENERATION lib 86f87852056008bf 86f8785200bf08bf 7f454c46010101 || return 1
done
unset _SURFACE_CHECK_ONLY
unset -f _PATCH_SURFACE_GENERATION
