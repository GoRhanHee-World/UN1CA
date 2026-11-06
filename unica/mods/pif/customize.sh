PIF_PATCH="0001-Introduce-PlayIntegrityHooks.patch"
if [ "$SOURCE_PLATFORM_SDK_VERSION" -ge 37 ]; then
    PIF_PATCH="0002-Introduce-PlayIntegrityHooks-oneui9.patch"
fi
APPLY_PATCH "system" "system/framework/framework.jar" "$MODPATH/framework.jar/$PIF_PATCH"
SMALI_PATCH "system" "system/framework/framework.jar" \
    "smali/android/app/Instrumentation.smali" "replace" \
    'newApplication(Ljava/lang/Class;Landroid/content/Context;)Landroid/app/Application;' \
    'return-object p0' \
    '    invoke-static {p1}, Lio/mesalabs/unica/PlayIntegrityHooks;->setProps(Landroid/content/Context;)V\n\n    return-object p0' \
    > /dev/null
SMALI_PATCH "system" "system/framework/framework.jar" \
    "smali/android/app/Instrumentation.smali" "replace" \
    'newApplication(Ljava/lang/ClassLoader;Ljava/lang/String;Landroid/content/Context;)Landroid/app/Application;' \
    'return-object p0' \
    '    invoke-static {p3}, Lio/mesalabs/unica/PlayIntegrityHooks;->setProps(Landroid/content/Context;)V\n\n    return-object p0' \
    > /dev/null
APPLY_PATCH "system" "system/framework/services.jar" "$MODPATH/services.jar/$PIF_PATCH"

KEYBOX_HOOKS="$(find "$APKTOOL_DIR/system/framework/framework.jar" \
    -path '*/io/mesalabs/unica/KeyboxImitationHooks.smali' -print -quit)"
if [ ! "$KEYBOX_HOOKS" ]; then
    PIF_HOOKS="$(find "$APKTOOL_DIR/system/framework/framework.jar" \
        -path '*/io/mesalabs/unica/PlayIntegrityHooks.smali' -printf '%P\n' -quit)"
    SMALI_PATCH "system" "system/framework/framework.jar" \
        "$PIF_HOOKS" "return" \
        'shouldBlockKeyAttestation()Z' 'true'
fi
unset PIF_PATCH KEYBOX_HOOKS PIF_HOOKS
