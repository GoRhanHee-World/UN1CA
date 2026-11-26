# shellcheck shell=bash
# shellcheck disable=SC2034
SKIPUNZIP=1

[ "$SOURCE_PLATFORM_SDK_VERSION" -ge 37 ] || return 0

APPLY_PATCH "system" "system/framework/framework.jar" \
    "$MODPATH/0001-Check-EngineeringMode-backend-availability.patch" || return 1
