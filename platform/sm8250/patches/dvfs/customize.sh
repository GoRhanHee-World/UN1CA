if [ "$SOURCE_PLATFORM_SDK_VERSION" -ge 37 ]; then
    SMALI_PATCH "system" "system/priv-app/SamsungDeviceHealthManagerService/SamsungDeviceHealthManagerService.apk" \
        "smali/c4/c.smali" "replace" '<clinit>()V' 'SM8350' 'SM8250'
    SMALI_PATCH "system" "system/priv-app/SamsungDeviceHealthManagerService/SamsungDeviceHealthManagerService.apk" \
        "smali/n5/i0.smali" "replace" '<clinit>()V' 'SM8350' 'SM8250'
    SMALI_PATCH "system" "system/priv-app/SamsungDeviceHealthManagerService/SamsungDeviceHealthManagerService.apk" \
        "smali/e4/o0.smali" "replaceall" 'TABoostControllerSM8350_SYSFS' 'TABoostControllerSM8250_SYSFS'

    # The donor's TABoost controller writes Sysfs IDs 0x301500, 0x301504
    # and 0x301507 on acquisition and release. None is registered by the
    # SM8250 vendor. Keep its DVFS locks and other boost handling intact.
    SMALI_PATCH "system" "system/priv-app/SamsungDeviceHealthManagerService/SamsungDeviceHealthManagerService.apk" \
        "smali/e4/o0.smali" "null" 'r()V'
    SMALI_PATCH "system" "system/priv-app/SamsungDeviceHealthManagerService/SamsungDeviceHealthManagerService.apk" \
        "smali/e4/o0.smali" "null" 'v()V'
else
    SMALI_PATCH "system" "system/priv-app/SamsungDeviceHealthManagerService/SamsungDeviceHealthManagerService.apk" \
        "smali/r1/c.smali" "replace" '<clinit>()V' 'SM8350' 'SM8250'
    APPLY_PATCH "system" "system/priv-app/SamsungDeviceHealthManagerService/SamsungDeviceHealthManagerService.apk" \
        "$MODPATH/legacy/0001-Restore-SM8250-TABoostController.patch"
fi

LOG_STEP_IN "- Removing unsupported SM8250 performance controls"
if ! command -v jq > /dev/null; then
    LOGE "jq is required to adapt the SM8250 Hyper configuration"
    return 1
fi
for HYPER_CONFIG in config_chipset.json config_vendor.json; do
    if [ -f "$WORK_DIR/vendor/etc/hyper/$HYPER_CONFIG" ]; then
        EVAL "bash \"$MODPATH/files/fix_hyper_config.sh\" \"$WORK_DIR/vendor/etc/hyper/$HYPER_CONFIG\"" || return 1
    fi
done
unset HYPER_CONFIG
EVAL "bash \"$MODPATH/files/fix_perf_config.sh\" \"$WORK_DIR/vendor/etc/perf\"" || return 1
LOG_STEP_OUT
