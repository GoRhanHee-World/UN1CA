SKIPUNZIP=1

LOG_STEP_IN "- Network mode list: publish the CSC default network type One UI 9 reads (I-52)"
_TUI="$WORK_DIR/system/system/priv-app/TelephonyUI/TelephonyUI.apk"
[ -f "$_TUI" ] || ABORT "[$TARGET_CODENAME] I-52: no system/priv-app/TelephonyUI/TelephonyUI.apk in work_dir - the donor moved it, re-read before shipping the bridge"
_N=0
for _DEX in $(unzip -Z1 "$_TUI" 'classes*.dex' 2>/dev/null); do
    unzip -p "$_TUI" "$_DEX" | grep -a -q 'persist.radio.def_network' && _N=$((_N + 1))
done
[ "$_N" -ge 1 ] || ABORT "[$TARGET_CODENAME] I-52: TelephonyUI no longer mentions persist.radio.def_network - the bridge would be dead, re-derive"

ADD_TO_WORK_DIR "$MODPATH" "system" "system/etc/init/minsos-radio-defnet.rc" 0 0 644 "u:object_r:system_file:s0"

_RC="$WORK_DIR/system/system/etc/init/minsos-radio-defnet.rc"
cmp -s "$MODPATH/system/etc/init/minsos-radio-defnet.rc" "$_RC" \
    || ABORT "[$TARGET_CODENAME] I-52: system/etc/init/minsos-radio-defnet.rc did not land in work_dir"
grep -q '^system/etc/init/minsos-radio-defnet.rc 0 0 644 ' "$WORK_DIR/configs/fs_config-system" \
    || ABORT "[$TARGET_CODENAME] I-52: minsos-radio-defnet.rc has no 0 0 644 fs_config entry"
grep -qxF '/system/etc/init/minsos-radio-defnet\.rc u:object_r:system_file:s0' "$WORK_DIR/configs/file_context-system" \
    || ABORT "[$TARGET_CODENAME] I-52: minsos-radio-defnet.rc has no system_file label"
LOG "- persist.radio.def_network follows ro.telephony.default_network (TelephonyUI reads it in $_N dex)"
unset _TUI _N _DEX _RC
LOG_STEP_OUT
