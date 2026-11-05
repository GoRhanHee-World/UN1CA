# shellcheck disable=SC2034
SKIPUNZIP=1

LOG_STEP_IN "- ueventd: the vendor's device rules where an Android 17 ueventd reads them"
_SDK="$(GET_PROP "system" "ro.build.version.sdk")"
if [ ! -f "$WORK_DIR/vendor/ueventd.rc" ]; then
    LOG "- Skipped: the vendor has no /vendor/ueventd.rc"
elif [ -f "$WORK_DIR/vendor/etc/ueventd.rc" ]; then
    LOG "- Skipped: the vendor already has /vendor/etc/ueventd.rc"
elif [ "${_SDK:-0}" -lt 37 ]; then
    LOG "- Skipped: sdk $_SDK still reads the legacy /vendor/ueventd.rc"
else
    EVAL "cp -a \"$WORK_DIR/vendor/ueventd.rc\" \"$WORK_DIR/vendor/etc/ueventd.rc\""
    SET_METADATA "vendor" "etc/ueventd.rc" 0 0 644 "u:object_r:vendor_configs_file:s0"

fi
LOG_STEP_OUT
unset _SDK
