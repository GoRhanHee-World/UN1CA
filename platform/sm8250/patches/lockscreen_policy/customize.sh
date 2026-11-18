# shellcheck shell=bash
# shellcheck disable=SC2034
SKIPUNZIP=1

[ "$SOURCE_PLATFORM_SDK_VERSION" -ge 37 ] || return 0

APPLY_PATCH "system" "system/framework/framework.jar" \
    "$MODPATH/0001-Disable-automatic-power-menu-lockdown.patch" || return 1
APPLY_PATCH "system" "system/framework/framework.jar" \
    "$MODPATH/0002-Remove-permanent-lock-attempt-warning-threshold.patch" || return 1
APPLY_PATCH "system" "system/system_ext/priv-app/SystemUI/SystemUI.apk" \
    "$MODPATH/0003-Disable-permanent-lock-in-both-keyguard-paths.patch" || return 1
