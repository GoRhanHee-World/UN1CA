SKIPUNZIP=1

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

[ -d "$FW_DIR/SM-G9860_TGY/vendor" ] || ABORT "[$TARGET_CODENAME] stock SM-G9860 TGY is not extracted at $FW_DIR/SM-G9860_TGY (ops/s20_series/extract_stock.sh)"
[ -d "$FW_DIR/SM-S9480_TGY/system/system/priv-app" ] \
    || ABORT "[$TARGET_CODENAME] stock SM-S9480 TGY is not extracted at $FW_DIR/SM-S9480_TGY (ops/s20_series/extract_stock_stream.sh)"
[ -z "$(find "$WORK_DIR/vendor" -iname '*soter@3.0*' -o -iname 'libSoterServiceImpl.so' -o -iname 'libTigerCaV4.so' | head -1)" ] \
    || ABORT "[$TARGET_CODENAME] the vendor already has Soter files - re-check before adding the TGY ones"

# path  uid gid mode label  sha256 (stock G9860ZHUCHZE1)
while read -r _F _U _G _M _L _S; do
    [ -n "$_F" ] || continue
    ADD_TO_WORK_DIR "SM-G9860/TGY" "vendor" "$_F" "$_U" "$_G" "$_M" "$_L"
    [ "$(sha256sum "$WORK_DIR/vendor/$_F" 2>/dev/null | cut -d' ' -f1)" = "$_S" ] \
        || ABORT "[$TARGET_CODENAME] vendor/$_F is missing or not the stock SM-G9860 file"
done <<'EOF'
bin/hw/vendor.samsung.hardware.soter@3.0-service 0 2000 755 u:object_r:hal_soter_sec_exec:s0 e23e0c22a2da91bd81e035b265f7e0cbf4caec559d11ce73387e2502d6a660c4
lib64/libSoterServiceImpl.so 0 0 644 u:object_r:vendor_file:s0 6c3a8365924f013dd92c8b05379226e592cf4cdd97fdad33ef45b07cae0a5793
lib64/libTigerCaV4.so 0 0 644 u:object_r:vendor_file:s0 c4c68ddb17d20bff1196d96e6454f26f147b4bebc7cae9f8cb4f6409deeb9422
lib64/libTigerLogger.so 0 0 644 u:object_r:vendor_file:s0 a12aeec78fd6cc84e71ca682f58ac0827ea57b0332df694bb0474986624cec92
lib64/vendor.samsung.hardware.soter@3.0.so 0 0 644 u:object_r:vendor_file:s0 525b67bdcecb2495b37c0c065ccd69da4ee003d7a33e374bce5e8673e591020f
EOF
cmp -s "$WORK_DIR/vendor/lib64/libQSEEComAPI.so" "$FW_DIR/SM-G9860_TGY/vendor/lib64/libQSEEComAPI.so" \
    || ABORT "[$TARGET_CODENAME] libQSEEComAPI.so differs from stock SM-G9860's - libTigerCaV4.so was built against it"
grep -q '^/(vendor|system/vendor)/bin/hw/vendor\\\.samsung\\\.hardware\\\.soter@3\\\.0-service *u:object_r:hal_soter_sec_exec:s0' \
    "$WORK_DIR/vendor/etc/selinux/vendor_file_contexts" \
    && grep -q '^vendor\.samsung\.hardware\.soter::ISehSoter *u:object_r:hal_sec_soter_hwservice:s0' \
        "$WORK_DIR/vendor/etc/selinux/vendor_hwservice_contexts" \
    || ABORT "[$TARGET_CODENAME] the vendor SELinux files no longer label the Soter HAL"

ADD_TO_WORK_DIR "$MODPATH/files" "vendor" "etc/init/minsos_soter_hk.rc" 0 0 644 "u:object_r:vendor_configs_file:s0"

# The manifest entry, as stock TGY declares it (before </manifest>, on every unit - see minsos_soter_hk.rc).
_M="$WORK_DIR/vendor/etc/vintf/manifest.xml"
[ "$(grep -c 'vendor\.samsung\.hardware\.soter' "$_M")" = 0 ] || ABORT "[$TARGET_CODENAME] the manifest already declares the Soter HAL"
[ "$(grep -c '^</manifest>$' "$_M")" = 1 ] || ABORT "[$TARGET_CODENAME] expected one </manifest> line in the vendor manifest"
sed -i 's|^</manifest>$|    <hal format="hidl">\n        <name>vendor.samsung.hardware.soter</name>\n        <transport>hwbinder</transport>\n        <version>3.0</version>\n        <interface>\n            <name>ISehSoter</name>\n            <instance>default</instance>\n        </interface>\n        <fqname>@3.0::ISehSoter/default</fqname>\n    </hal>\n</manifest>|' "$_M"
[ "$(grep -c '<name>vendor\.samsung\.hardware\.soter</name>' "$_M")" = 1 ] \
    && [ "$(grep -c '<fqname>@3.0::ISehSoter/default</fqname>' "$_M")" = 1 ] && [ "$(tail -1 "$_M")" = "</manifest>" ] \
    || ABORT "[$TARGET_CODENAME] the Soter manifest entry did not go in"

# The two system apps (apk only - stock TGY ships no oat for them).
for _A in SecSoterService:66e618393d06520ef9d582211af340767c80d53c78eab7c57d875339ada161bb \
          SoterSskdsSerivce:ebfacd7b43b02648a9a933f84df8ac9ca0a48990e9b86a6e85731061d0431992; do
    _N=${_A%%:*}
    [ ! -e "$WORK_DIR/system/system/priv-app/$_N" ] || ABORT "[$TARGET_CODENAME] system already has priv-app/$_N"
    ADD_TO_WORK_DIR "SM-S9480/TGY" "system" "system/priv-app/$_N"
    [ "$(sha256sum "$WORK_DIR/system/system/priv-app/$_N/$_N.apk" 2>/dev/null | cut -d' ' -f1)" = "${_A#*:}" ] \
        && [ "$(find "$WORK_DIR/system/system/priv-app/$_N" -type f | wc -l)" = 1 ] \
        || ABORT "[$TARGET_CODENAME] priv-app/$_N is missing, not the stock SM-S9480 apk, or brought more than the apk"
done
for _P in com.tencent.soter.soterserver com.samsung.android.sskds; do
    grep -q "<allowed-system-preload package=\"$_P\"/>" "$WORK_DIR/system/system/etc/sysconfig/allowed-system-preload-apps.xml" \
        || ABORT "[$TARGET_CODENAME] the donor's allowed-system-preload-apps.xml no longer lists $_P"
done
grep -q '<privapp-permissions package="com.tencent.soter.soterserver">' "$WORK_DIR/system/system/etc/permissions/privapp-permissions-platform.xml" \
    || ABORT "[$TARGET_CODENAME] the donor's privapp-permissions-platform.xml no longer lists com.tencent.soter.soterserver"

unset _F _U _G _M _L _S _A _N _P
LOG_STEP_OUT
