KERNELSU_MANAGER_APK="https://github.com/backslashxx/KernelSU/releases/download/v3.3.1%2B55/KernelSU_v3.3.1+55_32736-release.apk"
KERNELSU_MANAGER_SHA256="7302d6c92179f3a389510a818c52e73b2d957309f17a52bb53b4d9de25673895"
# https://github.com/tiann/KernelSU/issues/886
APK_PATH="system/preload/KernelSU/me.weishu.kernelsu-mesa==/base.apk"

LOG "- Adding xxKSU Manager v3.3.1+55 (32736) to preload apps"
mkdir -p "$WORK_DIR/system/$(dirname "$APK_PATH")"
DOWNLOAD_FILE "$KERNELSU_MANAGER_APK" "$WORK_DIR/system/$APK_PATH" || return 1
if ! printf '%s  %s\n' "$KERNELSU_MANAGER_SHA256" "$WORK_DIR/system/$APK_PATH" | sha256sum --check --status; then
    ABORT "KernelSU Manager APK is missing or its SHA-256 does not match the release"
    return 1
fi

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

unset KERNELSU_MANAGER_APK KERNELSU_MANAGER_SHA256 APK_PATH PRELOAD_APK_LIST
