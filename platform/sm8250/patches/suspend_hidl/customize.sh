# shellcheck disable=SC2034
SKIPUNZIP=1

if [ "$SOURCE_PLATFORM_SDK_VERSION" -ge 37 ]; then
    LOG_STEP_IN "- Bridging vendor HIDL wake locks to the AIDL suspend service"
    ADD_TO_WORK_DIR "$MODPATH/files" "system" "system/bin/hw/unica.system.suspend-hidl" \
        0 2000 755 "u:object_r:system_suspend_exec:s0"
    ADD_TO_WORK_DIR "$MODPATH/files" "system" "system/etc/init/unica.system.suspend-hidl.rc" \
        0 0 644 "u:object_r:system_file:s0"
    ADD_TO_WORK_DIR "$MODPATH/files" "system" "system/etc/vintf/manifest/unica.system.suspend-hidl.xml" \
        0 0 644 "u:object_r:system_file:s0"
    ADD_TO_WORK_DIR "$TARGET_FIRMWARE" "system" "system/lib64/android.system.suspend@1.0.so" \
        0 0 644 "u:object_r:system_lib_file:s0"

    if $TARGET_OS_BUILD_SYSTEM_EXT_PARTITION; then
        SUSPEND_SEPOLICY="$WORK_DIR/system_ext/etc/selinux/system_ext_sepolicy.cil"
    else
        SUSPEND_SEPOLICY="$WORK_DIR/system/system/system_ext/etc/selinux/system_ext_sepolicy.cil"
    fi
    if ! grep -q '^;; UN1CA SM8250 suspend bridge' "$SUSPEND_SEPOLICY"; then
        EVAL "cat \"$MODPATH/files/suspend_hidl_bridge.cil\" >> \"$SUSPEND_SEPOLICY\""
    fi
    unset SUSPEND_SEPOLICY
    LOG_STEP_OUT
fi
