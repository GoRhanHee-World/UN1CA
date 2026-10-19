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
    cmp -s "$WORK_DIR/vendor/ueventd.rc" "$WORK_DIR/vendor/etc/ueventd.rc" \
        || ABORT "! /vendor/etc/ueventd.rc is not a copy of /vendor/ueventd.rc"
    grep -q '^/dev/qseecom ' "$WORK_DIR/vendor/etc/ueventd.rc" \
        || ABORT "! /vendor/etc/ueventd.rc has no /dev/qseecom rule - Keymaster would still fail"
    grep -q '^vendor/etc/ueventd.rc 0 0 644 ' "$WORK_DIR/configs/fs_config-vendor" \
        || ABORT "! no fs_config entry for /vendor/etc/ueventd.rc - the image build dies on an unlisted path"
    grep -q '^/vendor/etc/ueventd\\.rc u:object_r:vendor_configs_file:s0' "$WORK_DIR/configs/file_context-vendor" \
        || ABORT "! /vendor/etc/ueventd.rc would ship unlabeled"
    LOG "- Added /vendor/etc/ueventd.rc ($(grep -c '^/dev/' "$WORK_DIR/vendor/etc/ueventd.rc") /dev rules) for sdk $_SDK"
fi
LOG_STEP_OUT
unset _SDK
