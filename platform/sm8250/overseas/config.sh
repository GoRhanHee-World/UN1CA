# shellcheck shell=bash
# Sourced after each S20 target's standard configuration.
# Released kernels carry verified overseas DTBO/NFC metadata. Keep an explicit
# Korean-only opt-out. Installer model checks do not require overseas firmware.
case "${SM8250_OVERSEAS:-1}" in
    0) TARGET_ASSERT_MODEL=("${TARGET_ASSERT_MODEL[0]}"); return 0 ;;
    1) ;;
    *) echo "SM8250_OVERSEAS must be 0 or 1" >&2; return 1 ;;
esac

# shellcheck disable=SC2034
case "$TARGET_CODENAME" in
    x1q) TARGET_ASSERT_MODEL=("SM-G981N" "SM-G9810" "SCG01" "SC-51A") ;;
    y2q) TARGET_ASSERT_MODEL=("SM-G986N" "SM-G9860" "SCG02" "SC-52A") ;;
    z3q) TARGET_ASSERT_MODEL=("SM-G988N" "SM-G9880" "SCG03") ;;
    *) echo "Overseas support is only defined for x1q, y2q and z3q" >&2; return 1 ;;
esac
