# shellcheck disable=SC2034
SKIPUNZIP=1

if [ "$SOURCE_PLATFORM_SDK_VERSION" -ge 35 ]; then
    LOG_STEP_IN "- Allowing fs-verity on package restrictions with the legacy ioctl hook"
    if $TARGET_OS_BUILD_SYSTEM_EXT_PARTITION; then
        FSVERITY_SEPOLICY="$WORK_DIR/system_ext/etc/selinux/system_ext_sepolicy.cil"
    else
        FSVERITY_SEPOLICY="$WORK_DIR/system/system/system_ext/etc/selinux/system_ext_sepolicy.cil"
    fi
    if [ ! -f "$FSVERITY_SEPOLICY" ]; then
        ABORT "Missing system_ext policy: $FSVERITY_SEPOLICY"
        return 1
    fi
    if ! grep -q '^;; UN1CA SM8250 fs-verity' "$FSVERITY_SEPOLICY"; then
        cat "$MODPATH/files/fsverity.cil" >> "$FSVERITY_SEPOLICY" || return 1
    fi
    unset FSVERITY_SEPOLICY
    LOG_STEP_OUT
fi
