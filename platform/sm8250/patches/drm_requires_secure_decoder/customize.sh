# shellcheck shell=bash
# shellcheck disable=SC2034
SKIPUNZIP=1

[ "$SOURCE_PLATFORM_SDK_VERSION" -ge 37 ] || return 0

# MinsOS I-172. The S928N EZK1 library matches the S948N BZK1 profile;
# the patcher verifies the ELF layout and instruction anchors before writing.
# shellcheck source=/dev/null
source "$MODPATH/drm_secure_decoder.sh" || return 1
PATCH_DRM_SECURE_DECODER \
    "$WORK_DIR/system/system/lib64/libmediadrm.so" || return 1
unset -f PATCH_DRM_SECURE_DECODER
