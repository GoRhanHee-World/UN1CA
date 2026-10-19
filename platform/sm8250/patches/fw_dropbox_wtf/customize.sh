SKIPUNZIP=1

LOG_STEP_IN "- Boot log: no dropbox wtf loop before DropBoxManagerService is published (9010 for One UI 9)"
_P="$MODPATH/9010-Skip-dropbox-before-it-is-published-oneui9.patch"
_REL="smali/com/android/server/am/ActivityManagerService.smali"
DECODE_APK "system" "system/framework/services.jar"
_D="$APKTOOL_DIR/system/framework/services.jar"
[ -f "$_D/$_REL" ] || ABORT "[$TARGET_CODENAME] 9010: $_REL is not in the decoded services.jar - the dex split moved, re-derive"
LC_ALL=C git -C / apply --check --directory="$_D" --unsafe-paths "$_P" 2>/dev/null \
    || ABORT "[$TARGET_CODENAME] 9010: the oneui9 guard does not apply to addErrorToDropBox - the donor changed, re-derive"
LC_ALL=C git -C / apply --directory="$_D" --unsafe-paths "$_P" \
    || ABORT "[$TARGET_CODENAME] 9010: git apply failed after a clean --check"

_G="$(awk '/^\.method .* addErrorToDropBox\(/,/^\.end method/' "$_D/$_REL" \
     | grep -E 'checkService\(Ljava/lang/String;\)|return-void|getSystemService' | head -3 \
     | sed -E 's/.*checkService.*/checkService/; s/.*getSystemService.*/getSystemService/; s/.*return-void.*/return-void/' | tr '\n' ' ')"
[ "$_G" = "checkService return-void getSystemService " ] \
    || ABORT "[$TARGET_CODENAME] 9010: addErrorToDropBox does not start with the guard: ${_G:-nothing}"
LOG "- addErrorToDropBox returns until the dropbox service is published"
unset _P _REL _D _G
LOG_STEP_OUT
