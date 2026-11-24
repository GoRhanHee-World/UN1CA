# shellcheck shell=bash
# Read by apply_modules.sh before sourcing this file.
# shellcheck disable=SC2034
SKIPUNZIP=1
case "$TARGET_CODENAME" in
    x1q|y2q|z3q) ;;
    *) return 0 ;;
esac
# The generated installer model list persists the overseas build selection.
case ":${TARGET_ASSERT_MODEL:-}:" in
    *:SM-G9810:*|*:SM-G9860:*|*:SM-G9880:*) ;;
    *) return 0 ;;
esac
[ "$SOURCE_PLATFORM_SDK_VERSION" -ge 37 ] || { ABORT "S20 overseas modules require Android 17 or newer"; return 1; }


# 11-04 owner ("넣고 모의 실행까지"): WeChat fingerprint payment (Soter) on the Hong Kong, China and Taiwan S20
# series. All three codenames: this tree builds x1q and z3q from target/y2q.
#
# MEASURED (ops/s20_series/SOTER_IFAA_FINDINGS_20261104.md):
#   - vendor: stock SM-G9860 TGY (G9860ZHUCHZE1) has vendor.samsung.hardware.soter@3.0-service and four libraries
#     the SM-G986N KOO vendor lacks (0 of 5); their other dependencies are system libraries or libQSEEComAPI.so,
#     which G986N ships byte-identical. TGY's manifest declares HIDL @3.0::ISehSoter/default; G986N's does not.
#   - SELinux: G986N already labels the binary hal_soter_sec_exec and maps vendor.samsung.hardware.soter::ISehSoter
#     to hal_sec_soter_hwservice; system_app may find it and call hal_soter_sec. Its soter rules equal TGY's.
#     No policy change.
#   - trustlet: libTigerCaV4.so loads it from /vendor/firmware_mnt/image (NON-HLOS, not in this ROM). TGY's
#     NON-HLOS has tigerfp (and ifbio); the G981N KOO one has neither. So the service starts only on G98x0.
#   - system: SecSoterService (com.tencent.soter.soterserver) and SoterSskdsSerivce (com.samsung.android.sskds)
#     from stock SM-S9480 TGY (S9480ZHS4BZIG). Platform certificate 34:DF:0E:7A... = the S948N donor's
#     framework-res. They carry their own HIDL/AIDL Soter stubs (no framework class outside them is needed),
#     ask for the HIDL HAL with getService() (no retry) and for the AIDL one with waitForDeclaredService (not
#     declared here), so on a unit without the service both return null at once. The donor's
#     privapp-permissions-platform.xml and allowed-system-preload-apps.xml already list both packages.
# NOT MEASURED: nothing of this has run on a G9810, G9860 or G9880; G9810/G9880 NON-HLOS and vendor were not
# checked (the G9860 HAL stands in for both). Whether WeChat's server accepts the model this ROM reports is unknown.
# Alipay (IFAA) is not added: S9480's framework.jar talks to AIDL vendor.samsung.hardware.ifaa.ISehIfaa and this
# vendor has only HIDL ifaa@1.0.

LOG_STEP_IN "- WeChat fingerprint payment (Soter) on the Hong Kong, China and Taiwan models"

[ -d "$SRC_DIR/prebuilts/samsung/g9860tgy/vendor" ] || { ABORT "Missing g9860tgy snapshot; run Update prebuilt blobs and merge the bot PR"; return 1; }
[ -d "$SRC_DIR/prebuilts/samsung/s9480tgy/system/priv-app" ] \
    || { ABORT "Missing s9480tgy snapshot; run Update prebuilt blobs and merge the bot PR"; return 1; }
[ -z "$(find "$WORK_DIR/vendor" -iname '*soter@3.0*' -o -iname 'libSoterServiceImpl.so' -o -iname 'libTigerCaV4.so' | head -1)" ] \
    || { ABORT "[$TARGET_CODENAME] the vendor already has Soter files - re-check before adding the TGY ones"; return 1; }

# path  uid gid mode label (stock G9860ZHUCHZE1)
while read -r _F _U _G _M _L; do
    [ -n "$_F" ] || continue
    ADD_TO_WORK_DIR "g9860tgy" "vendor" "$_F" "$_U" "$_G" "$_M" "$_L" || return 1
done <<'EOF'
bin/hw/vendor.samsung.hardware.soter@3.0-service 0 2000 755 u:object_r:hal_soter_sec_exec:s0
lib64/libSoterServiceImpl.so 0 0 644 u:object_r:vendor_file:s0
lib64/libTigerCaV4.so 0 0 644 u:object_r:vendor_file:s0
lib64/libTigerLogger.so 0 0 644 u:object_r:vendor_file:s0
lib64/vendor.samsung.hardware.soter@3.0.so 0 0 644 u:object_r:vendor_file:s0
EOF
cmp -s "$WORK_DIR/vendor/lib64/libQSEEComAPI.so" "$SRC_DIR/prebuilts/samsung/g9860tgy/vendor/lib64/libQSEEComAPI.so" \
    || { ABORT "[$TARGET_CODENAME] libQSEEComAPI.so differs from stock SM-G9860's - libTigerCaV4.so was built against it"; return 1; }
if ! grep -q '^/(vendor|system/vendor)/bin/hw/vendor\\\.samsung\\\.hardware\\\.soter@3\\\.0-service *u:object_r:hal_soter_sec_exec:s0' \
    "$WORK_DIR/vendor/etc/selinux/vendor_file_contexts" \
    || ! grep -q '^vendor\.samsung\.hardware\.soter::ISehSoter *u:object_r:hal_sec_soter_hwservice:s0' \
        "$WORK_DIR/vendor/etc/selinux/vendor_hwservice_contexts"; then
    ABORT "[$TARGET_CODENAME] the vendor SELinux files no longer label the Soter HAL"
    return 1
fi

ADD_TO_WORK_DIR "$MODPATH/files" "vendor" "etc/init/minsos_soter_hk.rc" 0 0 644 "u:object_r:vendor_configs_file:s0" || return 1

# Preserve the shared vendor's radio declarations and add Samsung Soter once.
bash "$SRC_DIR/platform/sm8250/overseas/vendor_manifest.sh" soter \
    "$WORK_DIR/vendor/etc/vintf/manifest.xml" || return 1

# The two system apps (apk only - stock TGY ships no oat for them).
for _N in SecSoterService SoterSskdsSerivce; do
    [ ! -e "$WORK_DIR/system/system/priv-app/$_N" ] || { ABORT "[$TARGET_CODENAME] system already has priv-app/$_N"; return 1; }
    ADD_TO_WORK_DIR "s9480tgy" "system" "system/priv-app/$_N" 0 0 755 "u:object_r:system_file:s0" || return 1
    SET_METADATA "system" "system/priv-app/$_N/$_N.apk" 0 0 644 "u:object_r:system_file:s0"
    if [ ! -f "$WORK_DIR/system/system/priv-app/$_N/$_N.apk" ] \
        || [ "$(find "$WORK_DIR/system/system/priv-app/$_N" -type f | wc -l)" != 1 ]; then
        ABORT "[$TARGET_CODENAME] priv-app/$_N is missing its apk or brought more than the apk"
        return 1
    fi
done
for _P in com.tencent.soter.soterserver com.samsung.android.sskds; do
    grep -q "<allowed-system-preload package=\"$_P\"/>" "$WORK_DIR/system/system/etc/sysconfig/allowed-system-preload-apps.xml" \
        || { ABORT "[$TARGET_CODENAME] the donor's allowed-system-preload-apps.xml no longer lists $_P"; return 1; }
done
grep -q '<privapp-permissions package="com.tencent.soter.soterserver">' "$WORK_DIR/system/system/etc/permissions/privapp-permissions-platform.xml" \
    || { ABORT "[$TARGET_CODENAME] the donor's privapp-permissions-platform.xml no longer lists com.tencent.soter.soterserver"; return 1; }

unset _F _U _G _M _L _N _P
LOG_STEP_OUT
