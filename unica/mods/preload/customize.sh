KERNELSU_MANAGER_APK="https://github.com/GoRhanHee-World/android_samsung_kernel_sm8250/releases/download/ksu_32737/KernelSU_v3.3.1-57-geeb3bbf8_32737-release.apk"
# https://github.com/tiann/KernelSU/issues/886
APK_PATH="system/preload/KernelSU/me.weishu.kernelsu-mesa==/base.apk"

LOG "- Adding KernelSU Manager v3.3.1-57-geeb3bbf8 (32737) to preload apps"
mkdir -p "$WORK_DIR/system/$(dirname "$APK_PATH")"
DOWNLOAD_FILE "$KERNELSU_MANAGER_APK" "$WORK_DIR/system/$APK_PATH" || return 1

# Samsung Internet Browser
# https://play.google.com/store/apps/details?id=com.sec.android.app.sbrowser
LOG "- Using Galaxy S26 Samsung Internet app"

PRELOAD_APK_LIST="$WORK_DIR/system/system/etc/vpl_apks_count_list.txt"
touch "$PRELOAD_APK_LIST" || return 1

while IFS= read -r i; do
    i="${i//$WORK_DIR\/system\//}"

    if [ -d "$WORK_DIR/system/$i" ]; then
        SET_METADATA "system" "$i" 0 0 755 "u:object_r:system_file:s0" || return 1
    else
        SET_METADATA "system" "$i" 0 0 644 "u:object_r:system_file:s0" || return 1
    fi

    if [[ "$i" == *".apk" ]] && \
            ! grep -qFx "/$i" "$PRELOAD_APK_LIST"; then
        LOG "- Adding \"$i\" to /system/system/etc/vpl_apks_count_list.txt"
        printf '/%s\n' "$i" >> "$PRELOAD_APK_LIST" || return 1
    fi
done <<< "$(find "$WORK_DIR/system/system/preload")"

unset KERNELSU_MANAGER_APK APK_PATH PRELOAD_APK_LIST
