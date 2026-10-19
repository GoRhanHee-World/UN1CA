SKIPUNZIP=1

LOG_STEP_IN "- UiccProfile: survive an empty perso status answer from the A13 RIL (SIM crash loop, r11)"
_P="$MODPATH/0001-Guard-short-perso-status-response.patch"
_REL='smali/com/android/internal/telephony/uicc/UiccProfile$5.smali'
DECODE_APK "system" "system/framework/telephony-common.jar"
_D="$APKTOOL_DIR/system/framework/telephony-common.jar"
[ -f "$_D/$_REL" ] || ABORT "[$TARGET_CODENAME] uicc_oem_guard: $_REL is not in the decoded telephony-common.jar - the dex split moved, re-derive"
LC_ALL=C git -C / apply --check --directory="$_D" --unsafe-paths "$_P" 2>/dev/null \
    || ABORT "[$TARGET_CODENAME] uicc_oem_guard: 0001 does not apply to UiccProfile\$5 - the donor changed, re-derive"
LC_ALL=C git -C / apply --directory="$_D" --unsafe-paths "$_P" \
    || ABORT "[$TARGET_CODENAME] uicc_oem_guard: git apply failed after a clean --check"

_F="$_D/$_REL"
_G="$(grep -n -x '    if-lt v0, v1, :minsos_perso_short' "$_F" | cut -d: -f1)"
_L="$(grep -n -x '    const-string v2, "EVENT_GET_PERSO_STATUS_COMPLETE"' "$_F" | cut -d: -f1)"
[ "$(wc -l <<< "$_G")" = 1 ] && [ "$(wc -l <<< "$_L")" = 1 ] && [ -n "$_G" ] && [ -n "$_L" ] \
    && [ "$(sed -n "$((_G - 6))p;$((_G - 4))p;$((_G - 2))p" "$_F" | tr '\n' '|')" = '    check-cast p1, [B|    array-length v0, p1|    const/4 v1, 0x2|' ] \
    && [ $((_L - _G)) -gt 0 ] && [ $((_L - _G)) -lt 12 ] \
    || ABORT "[$TARGET_CODENAME] uicc_oem_guard: the length test is not in front of the 110 handler's reads (guard=$_G read=$_L)"
[ "$(grep -c -x '    :minsos_perso_short' "$_F")" = 1 ] \
    && grep -A6 -x '    :minsos_perso_short' "$_F" | grep -qF -- '->-$$Nest$mloge(' \
    && grep -A8 -x '    :minsos_perso_short' "$_F" | grep -qx '    return-void' \
    || ABORT "[$TARGET_CODENAME] uicc_oem_guard: the :minsos_perso_short exit is missing or does not return"
LOG "- UiccProfile event 110 ignores a perso status answer shorter than two bytes"
unset _P _REL _D _F _G _L
LOG_STEP_OUT
