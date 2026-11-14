# Read by scripts/internal/apply_modules.sh before this file is sourced.
# shellcheck disable=SC2034
SKIPUNZIP=1

# Samsung's explicit dual-band channel lists require a bridged AP in Android 17.
# Keep one AP on S20 devices whose legacy Wi-Fi HAL lacks bridged AP support.
if [ "$SOURCE_PLATFORM_SDK_VERSION" -ge 37 ]; then
    APPLY_PATCH "system" "system/framework/semwifi-service.jar" \
        "$MODPATH/0001-Normalize-unsupported-bridged-hotspot-configurations.patch" || return 1
fi
