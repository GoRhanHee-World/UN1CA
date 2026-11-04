SKIPUNZIP=1

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
    y2q) _JP="SCG02/KDI"; _RF=6d776943ee8e8e7ed40e2fdb5e66d7406bbb0e9faaa3d32e19ad285d080aace2 ;;
    x1q) _JP="SCG01/KDI"; _RF=6448600887fa65a0d3974fe57b79eb8ddd6a74633614e1250f319f6891fef7c6 ;;
    *)   LOG "- nfc_jpn: x1q and y2q only (z3q's Japanese model has the NXP chip)"; return 0 ;;
esac

LOG_STEP_IN "- NFC on the Japanese $TARGET_CODENAME: Samsung SENN82AB HAL from stock ${_JP%/*}"

_JD="$FW_DIR/${_JP/\//_}/vendor"
[ -d "$_JD" ] || ABORT "[$TARGET_CODENAME] stock ${_JP%/*} is not extracted at $_JD (ops/s20_series/extract_stock.sh)"

# path  uid gid mode label  sha256 (stock SCG02KDS1DXB1 / SCG01KDS1DXB1: equal except the RF register file)
while read -r _F _U _G _M _L _S; do
    [ -n "$_F" ] || continue
    [ "$_S" != RF ] || _S=$_RF
    ADD_TO_WORK_DIR "$_JP" "vendor" "$_F" "$_U" "$_G" "$_M" "$_L"
    [ "$(sha256sum "$WORK_DIR/vendor/$_F" | cut -d' ' -f1)" = "$_S" ] \
        || ABORT "[$TARGET_CODENAME] vendor/$_F is not the stock ${_JP%/*} file"
    grep -q "^vendor/$_F " "$WORK_DIR/configs/fs_config-vendor" \
        || ABORT "[$TARGET_CODENAME] vendor/$_F has no fs_config entry"
done <<'EOF'
bin/hw/sec.android.hardware.nfc@1.2-service 0 2000 755 u:object_r:hal_nfc_default_exec:s0 6ede5f1b2c33ba66c00a4d4dc1b4e6e26ff3eccaacef81e17a0626f961cc1124
lib64/nfc_nci_fn.so 0 0 644 u:object_r:vendor_file:s0 0c5d1084258d9f8d23ea179e6e4eafb5117fb242772be2cda2422d4d248a7275
etc/libnfc-sec-vendor.conf 0 0 644 u:object_r:vendor_configs_file:s0 6f578f34d77924c4148a982d84047aa979310b5efa1cb892c001ca5ba75b07a6
etc/sec_senn82ab_rfreg.bin 0 0 644 u:object_r:vendor_configs_file:s0 RF
firmware/sec_senn82ab_firmware.bin 0 0 644 u:object_r:vendor_firmware_file:s0 27f1fde1caa1e9095898d8f09a6f8dc0f04513bbf109e6da5f32d1676c86b72d
EOF
cmp -s "$WORK_DIR/vendor/lib64/vendor.samsung.hardware.nfc@2.0.so" "$_JD/lib64/vendor.samsung.hardware.nfc@2.0.so" \
    || ABORT "[$TARGET_CODENAME] vendor.samsung.hardware.nfc@2.0.so differs from stock SCG02's - the SCG02 HAL was built against it"

ADD_TO_WORK_DIR "$MODPATH/files" "vendor" "etc/init/minsos_nfc_jpn.rc" 0 0 644 "u:object_r:vendor_configs_file:s0"

# The chip name moves from build.prop (read-only, first writer wins) to minsos_nfc_jpn.rc.
[ "$(GET_PROP "vendor" "ro.vendor.nfc.feature.chipname")" = "NXP_SN100U" ] \
    || ABORT "[$TARGET_CODENAME] vendor build.prop chip name is not NXP_SN100U - re-check before moving it"
SET_PROP "vendor" "ro.vendor.nfc.feature.chipname" --delete
[ -z "$(GET_PROP "vendor" "ro.vendor.nfc.feature.chipname")" ] \
    || ABORT "[$TARGET_CODENAME] ro.vendor.nfc.feature.chipname is still in vendor build.prop"

# The NXP rc must still be there and unchanged: it is what Korean and Hong Kong units start.
grep -q '^service vendor.nfc_hal_service /vendor/bin/hw/nxp.android.hardware.nfc@1.2-service$' \
    "$WORK_DIR/vendor/etc/init/nxp.android.hardware.nfc@1.2-service.rc" \
    || ABORT "[$TARGET_CODENAME] the NXP NFC HAL rc is missing or changed"
unset _JP _JD _RF _F _U _G _M _L _S
LOG_STEP_OUT
