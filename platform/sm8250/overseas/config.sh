# shellcheck shell=bash
# Sourced after each S20 target's standard configuration.
# Overseas inputs and installer assertions are opt-in until a matching kernel
# has been built; selecting this mode is persisted in TARGET_ASSERT_MODEL.
case "${SM8250_OVERSEAS:-0}" in
    0) return 0 ;;
    1) ;;
    *) echo "SM8250_OVERSEAS must be 0 or 1" >&2; return 1 ;;
esac

# shellcheck disable=SC2034
case "$TARGET_CODENAME" in
    x1q) TARGET_ASSERT_MODEL+=("SM-G9810" "SCG01" "SC-51A") ;;
    y2q) TARGET_ASSERT_MODEL+=("SM-G9860" "SCG02" "SC-52A") ;;
    z3q) TARGET_ASSERT_MODEL+=("SM-G9880" "SCG03") ;;
    *) echo "Overseas support is only defined for x1q, y2q and z3q" >&2; return 1 ;;
esac

# Keep the donor's dual-tray framework path for the mixed-model image. The
# model-selected vendor service still publishes one slot on Korean/Japanese units.
# shellcheck disable=SC2034
TARGET_RIL_SIM_CONFIG_MULTISIM_TRAYCOUNT="2"

# The module hashes pin the exact borrowed files. A different firmware revision
# must be reverified rather than accepted silently. See README.md for versions.
TARGET_EXTRA_FIRMWARES+=(
    "SM-G9860/TGY/350999641234561"
    "SCG02/KDI/350999641234561"
    "SM-S9480/TGY/350999641234561"
)
if [ "$TARGET_CODENAME" = x1q ]; then
    TARGET_EXTRA_FIRMWARES+=("SCG01/KDI/350999641234561")
fi
