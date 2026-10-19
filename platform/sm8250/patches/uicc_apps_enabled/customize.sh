SKIPUNZIP=1

LOG_STEP_IN "- GsmCdmaPhone: an unknown UICC apps state counts as enabled (no mobile data after SIM insert, r12)"
_P="$MODPATH/0001-Treat-unknown-UICC-apps-state-as-enabled.patch"
_REL='smali/com/android/internal/telephony/GsmCdmaPhone.smali'
DECODE_APK "system" "system/framework/telephony-common.jar"
_D="$APKTOOL_DIR/system/framework/telephony-common.jar"
[ -f "$_D/$_REL" ] || ABORT "[$TARGET_CODENAME] uicc_apps_enabled: $_REL is not in the decoded telephony-common.jar - the dex split moved, re-derive"
LC_ALL=C git -C / apply --check --directory="$_D" --unsafe-paths "$_P" 2>/dev/null \
    || ABORT "[$TARGET_CODENAME] uicc_apps_enabled: 0001 does not apply to GsmCdmaPhone - the donor changed, re-derive"
LC_ALL=C git -C / apply --directory="$_D" --unsafe-paths "$_P" \
    || ABORT "[$TARGET_CODENAME] uicc_apps_enabled: git apply failed after a clean --check"

_M="$(sed -n '/^\.method public blacklist isUiccApplicationsEnabled()Z$/,/^\.end method$/p' "$_D/$_REL" | grep -v '^$' | tr '\n' '|')"
[ "$_M" = '.method public blacklist isUiccApplicationsEnabled()Z|    .locals 0|    iget-object p0, p0, Lcom/android/internal/telephony/GsmCdmaPhone;->mUiccApplicationsEnabled:Ljava/lang/Boolean;|    if-nez p0, :cond_0|    const/4 p0, 0x1|    return p0|    :cond_0|    invoke-virtual {p0}, Ljava/lang/Boolean;->booleanValue()Z|    move-result p0|    return p0|.end method|' ] \
    || ABORT "[$TARGET_CODENAME] uicc_apps_enabled: isUiccApplicationsEnabled() is not the patched body after apply"
LOG "- GsmCdmaPhone.isUiccApplicationsEnabled() returns true while the RIL has not answered"
unset _P _REL _D _M
LOG_STEP_OUT
