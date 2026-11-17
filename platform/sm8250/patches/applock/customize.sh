# shellcheck shell=bash
# Samsung AppLock package and permission allowlist from MinsOS ea15a25e.
# Read by apply_modules.sh before sourcing this file.
# shellcheck disable=SC2034
SKIPUNZIP=1

case "$TARGET_CODENAME" in
    x1q|y2q|z3q) ;;
    *) return 0 ;;
esac

[ "$SOURCE_PLATFORM_SDK_VERSION" -ge 37 ] || return 0

SM8250_APPLOCK_APK="system/priv-app/AppLock/AppLock.apk"
SM8250_APPLOCK_XML="system/etc/permissions/privapp-permissions-com.samsung.android.applock.xml"
[ "$(sha256sum "$MODPATH/files/$SM8250_APPLOCK_APK" | cut -d ' ' -f 1)" = \
    "c920a9e9c92b07de158f224c13300b897d52f82addf2408936f168a26f4b8fa9" ] \
    || { ABORT "AppLock APK differs from the pinned Samsung build"; return 1; }
[ "$(sha256sum "$MODPATH/files/$SM8250_APPLOCK_XML" | cut -d ' ' -f 1)" = \
    "057bab82ff448848663be9411570fc01f10b2a04d0a8855e2b51f49e404bb199" ] \
    || { ABORT "AppLock privileged permission allowlist differs from the pinned file"; return 1; }
ADD_TO_WORK_DIR "$MODPATH/files" "system" "system/priv-app/AppLock" \
    0 0 755 "u:object_r:system_file:s0" || return 1
SET_METADATA "system" "$SM8250_APPLOCK_APK" 0 0 644 "u:object_r:system_file:s0"
ADD_TO_WORK_DIR "$MODPATH/files" "system" "$SM8250_APPLOCK_XML" \
    0 0 644 "u:object_r:system_file:s0" || return 1
unset SM8250_APPLOCK_APK SM8250_APPLOCK_XML

# Enable the framework and Settings only after the real unlock activity is installed.
APPLY_PATCH "system" "system/framework/framework.jar" \
    "$MODPATH/0001-Enable-AppLock-CoreRune.patch" || return 1
APPLY_PATCH "system" "system/priv-app/SecSettings/SecSettings.apk" \
    "$MODPATH/0002-Enable-AppLock-setting-oneui9.patch" || return 1
