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


# 11-04 owner "NFC 수정 ㄱㄱ": NFC on the Japanese S20+ (SCG02 au, SC-52A docomo).
#
# MEASURED (stock SCG02KDS1DXB1, ~/UN1CA/out/fw/SCG02_KDI, against SM-G986N_KOO and kernel 159176c6f4a2):
#   - chip: SCG02 has a Samsung SENN82AB (dtbo sec-nfc@27), the G986N an NXP SN100U (pn547@2B), same GPIOs
#     (irq 31, ven 8, firm 9) and supply. The KOR dtbo every Japanese unit on board-id 13/14 gets has only
#     pn547@2B, and the KOR kernel built only pn547 - kernel 0041 + CONFIG_SEC_NFC fix that half.
#   - HAL: sec.android.hardware.nfc@1.2-service and nxp.android.hardware.nfc@1.2-service declare the same
#     manifest entries (INfc 1.2 default, ISehNfc 2.0 default; the two manifest fragments are byte-identical),
#     so the vendor VINTF manifest stays as it is.
#   - SELinux: the G986N vendor already labels /vendor/bin/hw/sec.android.hardware.nfc@1.2-service
#     hal_nfc_default_exec and /dev/sec-nfc, /dev/sec-nfc-fn nfc_device, and its hal_nfc_default allow rules are
#     the SCG02 ones exactly (diff empty). No policy change.
#   - libraries: the HAL needs nfc_nci_fn.so (added) and vendor.samsung.hardware.nfc@2.0.so (G986N's is the same
#     file); the android.hardware.nfc@1.x interface libraries and the rest come from where the NXP HAL gets them.
# Start: files/vendor/etc/init/minsos_nfc_jpn.rc (why the NXP rc is left alone is written there).
# NOT MEASURED: nothing of this has run on an SCG02 or SC-52A. SC-52A shares the y2q JPN dts (felica_x1q_r10)
# but its stock firmware was not checked. FeliCa (Osaifu-Keitai) is not added: the S948N donor has no FeliCa
# middleware.
# x1q (SCG01, SC-51A), 11-04 (ops/s20_series/compare_scg01_20261104.txt, stock SCG01KDS1DXB1): the same chip
# (build.prop SENN82AB, dtbo sec-nfc@27) and the same HAL, library, configuration and firmware as SCG02 byte for
# byte; only the RF register file differs (tuned per antenna), so x1q takes that one from SCG01. The G981N
# vendor labels the HAL and /dev/sec-nfc the same way and ships the same vendor.samsung.hardware.nfc@2.0.so.
# z3q is left alone: its JPN dts keeps pn547@2B (NXP), so the SCG03 runs the HAL this vendor already has.
case "$TARGET_CODENAME" in
    y2q) _JP="scg02kdi" ;;
    x1q) _JP="scg01kdi" ;;
    *)   LOG "- nfc_jpn: x1q and y2q only (z3q's Japanese model has the NXP chip)"; return 0 ;;
esac

LOG_STEP_IN "- NFC on the Japanese $TARGET_CODENAME: Samsung SENN82AB HAL from stock ${_JP%/*}"

_JD="$SRC_DIR/prebuilts/samsung/$_JP/vendor"
[ -d "$_JD" ] || { ABORT "Missing $_JP snapshot; run Update prebuilt blobs and merge the bot PR"; return 1; }

# path  uid gid mode label (stock SCG02KDS1DXB1 / SCG01KDS1DXB1: equal except the RF register file)
while read -r _F _U _G _M _L; do
    [ -n "$_F" ] || continue
    ADD_TO_WORK_DIR "$_JP" "vendor" "$_F" "$_U" "$_G" "$_M" "$_L" || return 1
    grep -q "^vendor/$_F " "$WORK_DIR/configs/fs_config-vendor" \
        || { ABORT "[$TARGET_CODENAME] vendor/$_F has no fs_config entry"; return 1; }
done <<'EOF'
bin/hw/sec.android.hardware.nfc@1.2-service 0 2000 755 u:object_r:hal_nfc_default_exec:s0
lib64/nfc_nci_fn.so 0 0 644 u:object_r:vendor_file:s0
etc/libnfc-sec-vendor.conf 0 0 644 u:object_r:vendor_configs_file:s0
etc/sec_senn82ab_rfreg.bin 0 0 644 u:object_r:vendor_configs_file:s0
firmware/sec_senn82ab_firmware.bin 0 0 644 u:object_r:vendor_firmware_file:s0
EOF
cmp -s "$WORK_DIR/vendor/lib64/vendor.samsung.hardware.nfc@2.0.so" "$_JD/lib64/vendor.samsung.hardware.nfc@2.0.so" \
    || { ABORT "[$TARGET_CODENAME] vendor.samsung.hardware.nfc@2.0.so differs from stock SCG02's - the SCG02 HAL was built against it"; return 1; }

ADD_TO_WORK_DIR "$MODPATH/files" "vendor" "etc/init/minsos_nfc_jpn.rc" 0 0 644 "u:object_r:vendor_configs_file:s0" || return 1

# The chip name moves from build.prop (read-only, first writer wins) to minsos_nfc_jpn.rc.
[ "$(GET_PROP "vendor" "ro.vendor.nfc.feature.chipname")" = "NXP_SN100U" ] \
    || { ABORT "[$TARGET_CODENAME] vendor build.prop chip name is not NXP_SN100U - re-check before moving it"; return 1; }
SET_PROP "vendor" "ro.vendor.nfc.feature.chipname" --delete
[ -z "$(GET_PROP "vendor" "ro.vendor.nfc.feature.chipname")" ] \
    || { ABORT "[$TARGET_CODENAME] ro.vendor.nfc.feature.chipname is still in vendor build.prop"; return 1; }

# The NXP rc must still be there and unchanged: it is what Korean and Hong Kong units start.
grep -q '^service vendor.nfc_hal_service /vendor/bin/hw/nxp.android.hardware.nfc@1.2-service$' \
    "$WORK_DIR/vendor/etc/init/nxp.android.hardware.nfc@1.2-service.rc" \
    || { ABORT "[$TARGET_CODENAME] the NXP NFC HAL rc is missing or changed"; return 1; }
unset _JP _JD _F _U _G _M _L
LOG_STEP_OUT
