if [ "$SOURCE_PLATFORM_SDK_VERSION" -ge 37 ]; then
    SMALI_PATCH "system" "system/priv-app/SamsungDeviceHealthManagerService/SamsungDeviceHealthManagerService.apk" \
        "smali/c4/c.smali" "replace" '<clinit>()V' 'SM8350' 'SM8250'
    SMALI_PATCH "system" "system/priv-app/SamsungDeviceHealthManagerService/SamsungDeviceHealthManagerService.apk" \
        "smali/n5/i0.smali" "replace" '<clinit>()V' 'SM8350' 'SM8250'
    SMALI_PATCH "system" "system/priv-app/SamsungDeviceHealthManagerService/SamsungDeviceHealthManagerService.apk" \
        "smali/e4/o0.smali" "replaceall" 'TABoostControllerSM8350_SYSFS' 'TABoostControllerSM8250_SYSFS'
else
    SMALI_PATCH "system" "system/priv-app/SamsungDeviceHealthManagerService/SamsungDeviceHealthManagerService.apk" \
        "smali/r1/c.smali" "replace" '<clinit>()V' 'SM8350' 'SM8250'
    APPLY_PATCH "system" "system/priv-app/SamsungDeviceHealthManagerService/SamsungDeviceHealthManagerService.apk" \
        "$MODPATH/legacy/0001-Restore-SM8250-TABoostController.patch"
fi

LOG_STEP_IN "- Removing unsupported SM8250 performance controls"
for HYPER_CONFIG in config_chipset.json config_vendor.json; do
    if [ -f "$WORK_DIR/vendor/etc/hyper/$HYPER_CONFIG" ]; then
        EVAL "python3 \"$MODPATH/files/fix_hyper_config.py\" \"$WORK_DIR/vendor/etc/hyper/$HYPER_CONFIG\""
    fi
done
unset HYPER_CONFIG
LOG_STEP_OUT
