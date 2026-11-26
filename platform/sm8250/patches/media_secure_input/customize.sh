# shellcheck shell=bash
# shellcheck disable=SC2034
SKIPUNZIP=1

[ "$SOURCE_PLATFORM_SDK_VERSION" -ge 37 ] || return 0

# Tablet I-09 offsets do not apply to this phone donor. The patcher checks the
# S928N EZK1 ELF layout, both call sites, buffer layout and all injected bytes.
case "$SOURCE_FIRMWARE" in
    SM-S928N/*) ;;
    *) ABORT "Secure OMX input: no profile for $SOURCE_FIRMWARE"; return 1 ;;
esac

# shellcheck source=/dev/null
source "$MODPATH/secure_input.sh" || return 1
PATCH_MEDIA_SECURE_INPUT \
    "$WORK_DIR/system/system/lib64/libstagefright.so" || return 1
unset -f PATCH_MEDIA_SECURE_INPUT
