# shellcheck shell=bash
# Called by the common Settings mod after installing the UN1CA page.
case "$TARGET_CODENAME" in
    x1q|y2q|z3q) ;;
    *) return 0 ;;
esac
[ "$SOURCE_PLATFORM_SDK_VERSION" -ge 37 ] || return 0

LOG "- Adding the S20 series problem report collector to UN1CA Settings"
bash "$SRC_DIR/platform/sm8250/mods/settings/patch_settings.sh" \
    "$APKTOOL_DIR/system/priv-app/SecSettings/SecSettings.apk" || return 1
