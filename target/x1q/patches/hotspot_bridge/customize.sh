SKIPUNZIP=1

# Samsung's explicit dual-band channel lists require a bridged AP in Android 17.
# The x1q HIDL 1.4 HAL supports one AP, including automatic 2.4/5GHz selection.
if [ "$SOURCE_PLATFORM_SDK_VERSION" -ge 37 ]; then
    APPLY_PATCH "system" "system/framework/semwifi-service.jar" \
        "$MODPATH/0001-Normalize-unsupported-bridged-hotspot-configurations.patch" || return 1
fi
