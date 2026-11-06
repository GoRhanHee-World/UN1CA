DELETE_FROM_WORK_DIR "system" "system/etc/ldu_blocklist.xml"

if [ "$SOURCE_PLATFORM_SDK_VERSION" -ge "37" ]; then
    APPLY_PATCH "system" "system/framework/services.jar" \
        "$MODPATH/services-37.jar/0001-Allow-custom-PackageBlockListPolicy.patch"
else
APPLY_PATCH "system" "system/framework/services.jar" \
    "$MODPATH/services.jar/0001-Allow-custom-PackageBlockListPolicy.patch"
SMALI_PATCH "system" "system/framework/services.jar" \
    "smali_classes2/com/samsung/android/server/pm/install/PackageBlockListPolicy\$1.smali" 'remove'

fi
