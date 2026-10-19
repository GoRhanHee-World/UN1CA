# shellcheck disable=SC2034
SKIPUNZIP=1

APPLY_PATCH "system" "system/framework/services.jar" "$MODPATH/0001-Backport-legacy-SehLights-HAL-code.patch"
