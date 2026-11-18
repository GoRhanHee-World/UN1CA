# shellcheck shell=bash
# Work-profile compatibility from MinsOS 99722b9a (One UI 9).
# Read by apply_modules.sh before sourcing this file.
# shellcheck disable=SC2034
SKIPUNZIP=1
[ "$SOURCE_PLATFORM_SDK_VERSION" -ge 37 ] || return 0

_P="$MODPATH/0001-Allow-work-profiles-without-Knox-attestation-oneui9.patch"
_REL="smali_classes2/com/android/server/pm/UserManagerService.smali"
DECODE_APK "system" "system/framework/services.jar" || return 1
_D="$APKTOOL_DIR/system/framework/services.jar"
[ -f "$_D/$_REL" ] || { ABORT "[$TARGET_CODENAME] 9012: $_REL is not in the decoded services.jar - the dex split moved, re-derive"; return 1; }
LC_ALL=C git apply --check --directory="$_D" --unsafe-paths "$_P" 2>/dev/null \
    || { ABORT "[$TARGET_CODENAME] 9012: the oneui9 jump does not apply to UserManagerService - the donor changed, re-derive"; return 1; }
LC_ALL=C git apply --directory="$_D" --unsafe-paths "$_P" \
    || { ABORT "[$TARGET_CODENAME] 9012: git apply failed after a clean --check"; return 1; }

# Read back in verify_rom.sh's terms: the instruction before the attestation is a goto, and it lands
# where the goto after AttestationUtils.deleteKey lands. Label names only, so a renumbered donor
# that still applies cannot jump somewhere else unnoticed.
_B="$(awk '/^\.method .* createUserInternalUncheckedNoTracing\(/,/^\.end method/' "$_D/$_REL")"
_G="$(printf '%s\n' "$_B" | grep -B12 'const-string v0, "KnoxTestKeyUMS"' \
      | grep -vE '^\s*($|#|:|\.line|\.catch|const-string v0, "KnoxTestKeyUMS")' | tail -1 | awk '{print $1, $2}')"
_S="$(printf '%s\n' "$_B" | grep -A6 'AttestationUtils;->deleteKey(' | grep -m1 -E '^\s*goto' | awk '{print $2}')"
if [ -z "$_S" ] || [ "$_G" != "goto $_S" ]; then
    ABORT "[$TARGET_CODENAME] 9012: the attestation is entered by '${_G:-nothing}', not a goto to the passing label '${_S:-none}'"
    return 1
fi
LOG "- work profiles skip the KnoxTestKeyUMS attestation (jump to $_S)"
unset _P _REL _D _B _G _S
