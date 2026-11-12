# shellcheck disable=SC2034
SKIPUNZIP=1

case "$TARGET_CODENAME" in
    x1q|y2q|z3q)
        if [ "$SOURCE_PLATFORM_SDK_VERSION" -eq 37 ]; then
            APPLY_PATCH "system" "system/framework/secinputdev-service.jar" \
                "$MODPATH/0001-Honor-sysinput-activation-capability.patch"
        fi
        ;;
esac
