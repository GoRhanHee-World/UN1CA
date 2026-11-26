# shellcheck shell=bash
# shellcheck disable=SC2034
SKIPUNZIP=1

[ "$SOURCE_PLATFORM_SDK_VERSION" -ge 37 ] || return 0

# shellcheck source=/dev/null
source "$MODPATH/secure_input.sh" || return 1
PATCH_MEDIA_SECURE_INPUT \
    "$WORK_DIR/system/system/lib64/libstagefright.so" || return 1
unset -f PATCH_MEDIA_SECURE_INPUT
