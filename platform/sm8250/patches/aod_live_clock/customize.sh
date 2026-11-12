# shellcheck disable=SC2034
SKIPUNZIP=1

case "$TARGET_CODENAME" in
    x1q|y2q|z3q)
        if [ "$SOURCE_PLATFORM_SDK_VERSION" -eq 37 ]; then
            ADD_TO_WORK_DIR "$MODPATH/files" "system" "lib64/libunica_aod_jni.so" \
                0 0 644 "u:object_r:system_lib_file:s0"
            APPLY_PATCH "system" "system/framework/services.jar" \
                "$MODPATH/0001-Restore-native-live-clock-dispatch.patch"
        fi
        ;;
esac
