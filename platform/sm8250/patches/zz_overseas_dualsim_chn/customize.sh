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


# 11-04 owner (SM-G9860 TGY firmware supplied): the second SIM on the dual-SIM Hong Kong, China and Taiwan models.
# All three codenames: this tree builds x1q and z3q from target/y2q, and the parts below are the same on the three.
#
# MEASURED (stock G9860ZHUCHZE1 vs G986NKSS8IYC2, ops/s20_series/compare_g9860_20261104.txt):
#   - secril_config_svc: identical code (disassembly equal once addresses are normalised); the Korean binary
#     property_sets "1" and "ss", the TGY one "2" and "dsds". The G981N, G986N, G988N and SCG02 binaries are
#     byte-identical (be1e470b), so the TGY one stands in for G9810 and G9880 as well (their stock not checked).
#     Owner's G986N (r12 getprop, 10-08): ro.multisim.simslotcount 1, persist.radio.multisim.config ss.
#   - VINTF: TGY's manifest is G986N's plus slot2 of ISap, IRadio, ISehRadio, ISehBridge and epdgd2/imsd2 of
#     ISehChannel (radio_manifest_ds instead of _ss), and IFAA/Soter (Chinese payment HALs, not added). Radio rc
#     files (rilcommon, rilchip, init.qcom) are identical; the G981N/G988N radio entries equal G986N's.
#   - plmn_delta_hktw.bin (TGY) and plmn_delta_jpnkdi.bin (SCG02): the Korean libsec-ril.so already names both.
# NOT MEASURED: no Hong Kong, China or Taiwan unit has run this. The RIL libraries stay Korean (same dual-SIM
# strings as TGY's, different builds).

LOG_STEP_IN "- Second SIM on the Hong Kong, China and Taiwan models"

_H="$SRC_DIR/prebuilts/samsung/g9860tgy/vendor"
[ -d "$_H" ] || { ABORT "Missing g9860tgy snapshot; run Update prebuilt blobs and merge the bot PR"; return 1; }

# The TGY binary under its own name, next to the Korean one.
_T=$(mktemp -d)
mkdir -p "$_T/vendor/bin"
cp -a "$_H/bin/secril_config_svc" "$_T/vendor/bin/secril_config_svc_ds" || return 1
ADD_TO_WORK_DIR "$_T" "vendor" "bin/secril_config_svc_ds" 0 2000 755 "u:object_r:vendor_secril_config_svc_exec:s0" || return 1
rm -rf "$_T"

# Network name tables the Korean libsec-ril.so looks for.
ADD_TO_WORK_DIR "g9860tgy" "vendor" "etc/plmn_delta_hktw.bin" 0 0 644 "u:object_r:vendor_configs_file:s0" || return 1
ADD_TO_WORK_DIR "scg02kdi" "vendor" "etc/plmn_delta_jpnkdi.bin" 0 0 644 "u:object_r:vendor_configs_file:s0" || return 1
# sim_config moves from rilcommon's "on fs" to minsos_dualsim.rc.
_R="$WORK_DIR/vendor/etc/init/init.vendor.rilcommon.rc"
[ "$(grep -c '^    exec_start sim_config$' "$_R")" = 1 ] || { ABORT "[$TARGET_CODENAME] rilcommon.rc does not start sim_config exactly once"; return 1; }
sed -i '/^on fs$/{N;/\n    exec_start sim_config$/d}' "$_R"
if grep -q 'exec_start sim_config' "$_R" || ! grep -q '^service sim_config /vendor/bin/secril_config_svc SimConfig$' "$_R"; then
    ABORT "[$TARGET_CODENAME] rilcommon.rc still starts sim_config, or lost its definition"
    return 1
fi
ADD_TO_WORK_DIR "$MODPATH/files" "vendor" "etc/init/minsos_dualsim.rc" 0 0 644 "u:object_r:vendor_configs_file:s0" || return 1

# The shared UN1CA vendor already declares the second radio slot.
bash "$SRC_DIR/platform/sm8250/overseas/vendor_manifest.sh" radio \
    "$WORK_DIR/vendor/etc/vintf/manifest.xml" || return 1
unset _H _T _R _M
LOG_STEP_OUT
