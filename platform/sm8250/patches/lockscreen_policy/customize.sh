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

# The S20 vendor lacks the donor's AIDL Engineering Mode service. Querying
# EM token 64 blocks the credential confirmation UI for five seconds.
SMALI_PATCH "system" "system/priv-app/SecSettings/SecSettings.apk" \
    "smali_classes3/com/samsung/android/settings/lockscreen/LockUtils.smali" \
    "return" "isEmTokenAllowed(Lcom/android/settings/SettingsActivity;)Z" "false" || return 1
