SKIPUNZIP=1

LOG_STEP_IN "- Shizuku: IProcessObserver tolerates a missing onProcessStarted (9004 for One UI 9)"
_P="$MODPATH/9004-Make-IProcessObserver-tolerate-missing-onProcessStarted-oneui9.patch"
_REL='smali/android/app/IProcessObserver$Stub.smali'
DECODE_APK "system" "system/framework/framework.jar"
_D="$APKTOOL_DIR/system/framework/framework.jar"
[ -f "$_D/$_REL" ] || ABORT "[$TARGET_CODENAME] 9004: $_REL is not in the decoded framework.jar - the dex split moved, re-derive"
LC_ALL=C git -C / apply --check --directory="$_D" --unsafe-paths "$_P" 2>/dev/null \
    || ABORT "[$TARGET_CODENAME] 9004: the oneui9 catch does not apply to IProcessObserver\$Stub - the donor changed, re-derive"
LC_ALL=C git -C / apply --directory="$_D" --unsafe-paths "$_P" \
    || ABORT "[$TARGET_CODENAME] 9004: git apply failed after a clean --check"

_BODY="$(awk '/^\.method public whitelist onTransact\(ILandroid\/os\/Parcel;Landroid\/os\/Parcel;I\)Z/,/^\.end method/' "$_D/$_REL")"
_T="$(grep -A1 -x '    :try_start_ipo' <<< "$_BODY" | tail -1)"
grep -qF 'invoke-virtual/range {v1 .. v6}, Landroid/app/IProcessObserver$Stub;->onProcessStarted(IIILjava/lang/String;Ljava/lang/String;)V' <<< "$_T" \
    && grep -qxF '    .catch Ljava/lang/AbstractMethodError; {:try_start_ipo .. :try_end_ipo} :catch_ipo' <<< "$_BODY" \
    && grep -A1 -x '    :catch_ipo' <<< "$_BODY" | grep -qx '    move-exception v1' \
    || ABORT "[$TARGET_CODENAME] 9004: onTransact was not rewritten: $(tr '\n' ' ' <<< "$_BODY" | tail -c 600)"
LOG "- IProcessObserver\$Stub.onTransact catches AbstractMethodError from onProcessStarted"
unset _P _REL _D _BODY _T
LOG_STEP_OUT
