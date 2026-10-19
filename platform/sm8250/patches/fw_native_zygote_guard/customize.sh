SKIPUNZIP=1

LOG_STEP_IN "- Native app zygote: give up on a dead child after 12 s, close failed sockets (framework.jar)"
_P="$MODPATH/0001-Give-up-on-a-dead-native-app-zygote-after-12s.patch"
_REL="smali_classes3/android/os/ZygoteProcess.smali"
DECODE_APK "system" "system/framework/framework.jar"
_D="$APKTOOL_DIR/system/framework/framework.jar"
[ -f "$_D/$_REL" ] || ABORT "[$TARGET_CODENAME] native zygote guard: $_REL is not in the decoded framework.jar - the dex split moved, re-derive"
LC_ALL=C git -C / apply --check --directory="$_D" --unsafe-paths "$_P" 2>/dev/null \
    || ABORT "[$TARGET_CODENAME] native zygote guard does not apply to waitForConnectionToZygote - the donor changed, re-derive"
LC_ALL=C git -C / apply --directory="$_D" --unsafe-paths "$_P" \
    || ABORT "[$TARGET_CODENAME] native zygote guard: git apply failed after a clean --check"

_G="$(awk '/^\.method .* waitForConnectionToZygote\(Landroid\/net\/LocalSocketAddress;Z\)V/,/^\.end method/' "$_D/$_REL" \
     | grep -oE 'const/16 v0, 0x2ee0|const/16 v0, 0x898|IoUtils;->closeQuietly' | tr '\n' ' ')"
[ "$_G" = "const/16 v0, 0x2ee0 const/16 v0, 0x898 IoUtils;->closeQuietly " ] \
    || ABORT "[$TARGET_CODENAME] native zygote guard: the method does not read back as patched: ${_G:-nothing}"
LOG "- waitForConnectionToZygote: native bound 0x898 (~12 s), failed sockets closed"
unset _P _REL _D _G
LOG_STEP_OUT
