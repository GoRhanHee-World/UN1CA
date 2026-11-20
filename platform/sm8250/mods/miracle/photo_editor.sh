# shellcheck shell=bash
# Keep the complete One UI 9 editor for the S23's legacy SNAP/model interface.
# The S26 editor expects separately distributed SmartAIEngine/ObjectRemoval
# providers that are not part of the SM8250 image.
EDITOR_SOURCE="$FW_DIR/SM-S911N_KOO/system/system"
[ -d "$EDITOR_SOURCE" ] || EDITOR_SOURCE="$FW_DIR/SM-S911N_KOO/system"
EDITOR_DIR=""
for EDITOR_CANDIDATE in PhotoEditor_AIFull PhotoEditor_Full; do
    if [ -f "$EDITOR_SOURCE/priv-app/$EDITOR_CANDIDATE/$EDITOR_CANDIDATE.apk" ]; then
        EDITOR_DIR="$EDITOR_CANDIDATE"
        break
    fi
done
[ -n "$EDITOR_DIR" ] || { ABORT "One UI 9 S23 Photo Editor is missing"; return 1; }
LOG_STEP_IN "- Pairing Photo Editor with the legacy SNAP model interface"
for EDITOR_CANDIDATE in PhotoEditor_AIFull PhotoEditor_Full; do
    if [ -d "$WORK_DIR/system/system/priv-app/$EDITOR_CANDIDATE" ]; then
        DELETE_FROM_WORK_DIR "system" "system/priv-app/$EDITOR_CANDIDATE"
    fi
done
ADD_TO_WORK_DIR "SM-S911N/KOO" "system" "system/priv-app/$EDITOR_DIR" || return 1
for EDITOR_POLICY in \
    permissions/privapp-permissions-com.sec.android.mimage.photoretouching.xml \
    sysconfig/preinstalled-packages-com.sec.android.mimage.photoretouching.xml; do
    ADD_TO_WORK_DIR "SM-S911N/KOO" "system" "system/etc/$EDITOR_POLICY" 0 0 644 "u:object_r:system_file:s0" || return 1
done
# The reference port leaves the unvalidated S26 foundational segmenter disabled.
SET_FLOATING_FEATURE_CONFIG "SEC_FLOATING_FEATURE_VIDEO_CONFIG_VIDEO_CLIPPING_MODE" "NPU"
LOG_STEP_OUT
unset EDITOR_SOURCE EDITOR_DIR EDITOR_CANDIDATE EDITOR_POLICY
