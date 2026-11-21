#!/usr/bin/env bash
# Copyright (c) 2026
# SPDX-License-Identifier: GPL-3.0-or-later

# shellcheck disable=SC2034
SKIPUNZIP=1
if [ "$SOURCE_PLATFORM_SDK_VERSION" -lt 37 ]; then
    return 0
fi

# Keep the source firmware's WFD executable, libraries, app and framework as a
# set. The old R9q ARM32 overlay requires Qualcomm display/QSEE interfaces the
# SM8250 system does not supply. Its AudioTrack/vtable shims cannot repair that.
# The vendor OMX service stays ARM32; I-08 bridges metadata on the ARM64 client.
for WFD_FILE in bin/remotedisplay lib64/libremotedisplay.so \
        lib64/libremotedisplay_wfd.so lib64/libremotedisplayservice.so \
        lib64/libstagefright.so; do
    if ! WFD_ELF_HEADER="$(LC_ALL=C readelf -h "$WORK_DIR/system/system/$WFD_FILE" 2>/dev/null)"; then
        ABORT "Missing or invalid donor WFD file: $WFD_FILE"
        return 1
    fi
    if ! grep -q 'Class:.*ELF64' <<< "$WFD_ELF_HEADER" ||
            ! grep -q 'Machine:.*AArch64' <<< "$WFD_ELF_HEADER"; then
        ABORT "WFD requires the source firmware's ARM64 $WFD_FILE; recreate the work directory without the old ARM32 overlay"
        return 1
    fi
done
unset WFD_FILE WFD_ELF_HEADER

# Abort on an unknown donor instead of shipping a Smart View fix that skipped.
source "$MODPATH/i08_marshal.sh" || return 1

# This ARM32 library is still used by other legacy media clients. Retain its
# existing FORTIFY fix independently of the WFD executable's architecture.
if [ -f "$WORK_DIR/system/system/lib/libstagefright.so" ]; then
    WFD_STAGEFRIGHT_HEX="$(xxd -p -c 0 "$WORK_DIR/system/system/lib/libstagefright.so")"
    if [[ "$WFD_STAGEFRIGHT_HEX" == *204601214ff400722b46* ]]; then
        HEX_PATCH "$WORK_DIR/system/system/lib/libstagefright.so" \
            "204601214ff400722b46" "204601214ff0fe022b46" || return 1
    elif [[ "$WFD_STAGEFRIGHT_HEX" == *01214ff4007230462b460097* ]]; then
        HEX_PATCH "$WORK_DIR/system/system/lib/libstagefright.so" \
            "01214ff4007230462b460097" "01214ff0fe0230462b460097" || return 1
    fi
    unset WFD_STAGEFRIGHT_HEX
fi

# Apply explicitly so older Android releases keep their existing WFD behavior.
APPLY_PATCH "system" "system/framework/services.jar" \
    "$MODPATH/patches/0001-Recover-from-RemoteDisplay-listen-failure.patch" || return 1
