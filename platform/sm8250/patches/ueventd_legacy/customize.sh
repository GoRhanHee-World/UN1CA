# shellcheck disable=SC2034
SKIPUNZIP=1

LOG_STEP_IN "- Importing legacy vendor device permissions"
_SDK="$(GET_PROP "system" "ro.build.version.sdk")"
if [ ! -f "$WORK_DIR/vendor/ueventd.rc" ]; then
    LOG "- Skipped: the vendor has no /vendor/ueventd.rc"
elif [ "${_SDK:-0}" -lt 37 ]; then
    LOG "- Skipped: sdk $_SDK still reads the legacy /vendor/ueventd.rc"
elif cmp -s "$WORK_DIR/vendor/ueventd.rc" "$WORK_DIR/vendor/etc/ueventd.rc" || \
        grep -qE '^[[:space:]]*import[[:space:]]+/vendor/ueventd\.rc([[:space:]]|$)' "$WORK_DIR/vendor/etc/ueventd.rc" 2> /dev/null; then
    LOG "- Legacy vendor device permissions are already included"
else
    mkdir -p "$WORK_DIR/vendor/etc"
    printf '\nimport /vendor/ueventd.rc\n' >> "$WORK_DIR/vendor/etc/ueventd.rc"
    SET_METADATA "vendor" "etc/ueventd.rc" 0 0 644 "u:object_r:vendor_configs_file:s0"
fi
LOG_STEP_OUT
unset _SDK
