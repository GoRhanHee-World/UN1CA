# shellcheck disable=SC2034
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
        while IFS= read -r _F; do
            perl -0777 -i -pe '
                s{invoke-static \{\}, Landroid/os/Debug;->getGpu(?:TotalUsageKb|PrivateMemoryKb)\(\)J\n\n(\s*)move-result-wide (v\d+)}
                 {const-wide/16 $2, -0x1}g;
            ' "$_F"
            _N=$((_N + 1))
            LOG "- ${_F#"$APKTOOL_DIR"/}"
        done < <(grep -rl 'Landroid/os/Debug;->getGpu\(TotalUsageKb\|PrivateMemoryKb\)()J' "$_D" 2>/dev/null)
    done
    LOG "- $_N file(s) now get -1 instead of the native GPU read"
fi
LOG_STEP_OUT
unset _SDK _N _J _D _F
