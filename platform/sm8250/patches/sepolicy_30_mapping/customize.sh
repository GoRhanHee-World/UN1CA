# shellcheck disable=SC2034
SKIPUNZIP=1

LOG_STEP_IN "- SELinux 30.0 vendor mapping for an Android 17 system"
_V="$(head -n 1 "$WORK_DIR/vendor/etc/selinux/plat_sepolicy_vers.txt")"
if [ "$_V" != "30.0" ]; then
    LOG "- Skipped: the vendor policy is $_V, these files are for 30.0"
    LOG_STEP_OUT; unset _V; return 0
fi
if [ -f "$WORK_DIR/system/system/etc/selinux/mapping/30.0.cil" ]; then
    LOG "- Skipped: the donor still ships its own 30.0.cil (Android 16 or older)"
    LOG_STEP_OUT; unset _V; return 0
fi

_SFM_ADD()
{
    local f
    for f in "$MODPATH/files/$1/"*.cil; do
        EVAL "cp -a \"$f\" \"$WORK_DIR/$2/$(basename "$f")\""
        SET_METADATA "$3" "$4/$(basename "$f")" 0 0 644 "u:object_r:system_file:s0"
        LOG "- Added $2/$(basename "$f")"
    done
}
_SFM_ADD system "system/system/etc/selinux/mapping" system "system/etc/selinux/mapping"
if $TARGET_OS_BUILD_SYSTEM_EXT_PARTITION; then
    _SFM_ADD system_ext "system_ext/etc/selinux/mapping" system_ext "etc/selinux/mapping"
else
    _SFM_ADD system_ext "system/system/system_ext/etc/selinux/mapping" system "system/system_ext/etc/selinux/mapping"
fi
_SFM_ADD product "product/etc/selinux/mapping" product "etc/selinux/mapping"

LOG_STEP_OUT
unset _V
unset -f _SFM_ADD
