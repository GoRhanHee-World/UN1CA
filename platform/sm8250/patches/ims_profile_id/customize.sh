SKIPUNZIP=1

LOG_STEP_IN "- Sending the vendor RIL plain data profile ids (IMS calls on Korean carriers, I-43)"
SMALI_PATCH "system" "system/framework/telephony-common.jar" \
    "smali/com/android/internal/telephony/RILUtils.smali" "return" \
    "IsApAssistSupported()Z" "false"

_RU="$(RESOLVE_SMALI "system" "framework/telephony-common.jar" "smali/com/android/internal/telephony/RILUtils.smali")"
[ -f "$_RU" ] || ABORT "[$TARGET_CODENAME] RILUtils.smali missing - telephony-common.jar layout changed"
_BODY="$(awk '/^\.method .*IsApAssistSupported\(\)Z/ {f=1} f {print} f && /^\.end method/ {exit}' "$_RU")"
[ -n "$_BODY" ] || ABORT "[$TARGET_CODENAME] IsApAssistSupported()Z not found in RILUtils"
grep -qx '    const/4 v0, 0x0' <<< "$_BODY" && grep -qx '    return v0' <<< "$_BODY" && ! grep -q 'invoke-' <<< "$_BODY" \
    || ABORT "[$TARGET_CODENAME] IsApAssistSupported() was not rewritten to return false: $(tr '\n' ' ' <<< "$_BODY")"
grep -q 'invoke-static {}, Lcom/android/internal/telephony/RILUtils;->IsApAssistSupported()Z' "$_RU" \
    || ABORT "[$TARGET_CODENAME] makeProfileId no longer calls IsApAssistSupported - re-read the donor before shipping this"
unset _RU _BODY
LOG "- RILUtils.IsApAssistSupported() returns false: profile ids go out unfolded"
LOG_STEP_OUT
