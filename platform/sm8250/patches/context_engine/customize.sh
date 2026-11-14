# shellcheck disable=SC2034
SKIPUNZIP=1

if [ "$SOURCE_PLATFORM_SDK_VERSION" -ge 37 ]; then
    APPLY_PATCH "system" "system/framework/services.jar" \
        "$MODPATH/0001-Isolate-legacy-biometric-HAL-selection-and-restore-ContextEngine.patch" || return 1
fi
