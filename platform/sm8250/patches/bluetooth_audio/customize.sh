# shellcheck shell=bash
# MinsOS bf5b995d (I-187): some cars select a primary-HAL offload output even
# though this vendor's Bluetooth stack opens a software-encoding session.
case "$TARGET_CODENAME" in x1q|y2q|z3q) ;; *) return 0 ;; esac
SET_PROP "vendor" "persist.bluetooth.a2dp_offload.disabled" "true" || return 1
grep -qx 'persist.bluetooth.a2dp_offload.disabled=true' "$WORK_DIR/vendor/build.prop" \
    || { ABORT "A2DP software audio path was not enabled in vendor/build.prop"; return 1; }
if grep -qx 'persist.bluetooth.a2dp_offload.disabled=false' \
        "$WORK_DIR/vendor/build.prop" "$WORK_DIR/vendor/default.prop" 2>/dev/null; then
    ABORT "A conflicting A2DP offload property remains in the vendor props"
    return 1
fi
