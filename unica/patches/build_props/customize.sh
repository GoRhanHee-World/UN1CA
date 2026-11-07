if [ "$SOURCE_PLATFORM_SDK_VERSION" -ge 37 ]; then
    DECODE_APK "system" "system/framework/framework.jar"
    for BUILD_CLASS in Build "Build\$VERSION"; do
        BUILD_SMALI="$(find "$APKTOOL_DIR/system/framework/framework.jar" \
            -path "*/android/os/$BUILD_CLASS.smali" -print -quit)"
        if [ ! "$BUILD_SMALI" ]; then
            ABORT "Missing android.os.$BUILD_CLASS in framework.jar"
            return 1
        fi

        if [ "$BUILD_CLASS" = Build ]; then
            BUILD_FIELDS="BRAND DEVICE FINGERPRINT ID MANUFACTURER MODEL PRODUCT TYPE"
        else
            BUILD_FIELDS="DEVICE_INITIAL_SDK_INT INCREMENTAL RELEASE SECURITY_PATCH SEM_FIRST_SDK_INT"
        fi
        for BUILD_FIELD in $BUILD_FIELDS; do
            sed -i -E "/^\\.field .* $BUILD_FIELD:/s/ static final / static /" "$BUILD_SMALI"
        done
    done
    unset BUILD_CLASS BUILD_SMALI BUILD_FIELDS BUILD_FIELD
fi
