SKIPUNZIP=1


LOG_STEP_IN "- GPU memory stats: callers skip the BPF read the 4.19 kernel cannot back"
_SDK="$(GET_PROP "system" "ro.build.version.sdk")"
if [ "${_SDK:-0}" -lt 37 ]; then
    LOG "- Skipped: sdk $_SDK libmeminfo does not abort on a missing gpu_mem map"
else
    DECODE_APK "system" "system/framework/framework.jar"
    DECODE_APK "system" "system/framework/services.jar"
    _N=0
    for _J in framework.jar services.jar; do
        _D="$APKTOOL_DIR/system/framework/$_J"
        [ -d "$_D" ] || ABORT "! $_J is not decoded at ${_D#"$APKTOOL_DIR"/}"
        while IFS= read -r _F; do
            perl -0777 -i -pe '
                s{invoke-static \{\}, Landroid/os/Debug;->getGpu(?:TotalUsageKb|PrivateMemoryKb)\(\)J\n\n(\s*)move-result-wide (v\d+)}
                 {const-wide/16 $2, -0x1}g;
            ' "$_F"
            _N=$((_N + 1))
            LOG "- ${_F#"$APKTOOL_DIR"/}"
        done < <(grep -rl 'Landroid/os/Debug;->getGpu\(TotalUsageKb\|PrivateMemoryKb\)()J' "$_D" 2>/dev/null)
    done
    _LEFT="$(grep -rl 'Landroid/os/Debug;->getGpu\(TotalUsageKb\|PrivateMemoryKb\)()J' "$APKTOOL_DIR/system/framework/framework.jar" "$APKTOOL_DIR/system/framework/services.jar" 2>/dev/null | grep -c . || true)"
    [ "${_LEFT:-0}" = 0 ] || ABORT "! $_LEFT file(s) still call Debug.getGpu* - the call shape changed, re-derive this patch"
    [ "$_N" -ge 1 ] || LOGW "no Debug.getGpu* callers found - nothing to guard (check the donor)"
    LOG "- $_N file(s) now get -1 instead of the native GPU read"
fi
LOG_STEP_OUT
unset _SDK _N _J _D _F _LEFT
