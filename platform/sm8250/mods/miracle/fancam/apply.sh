# shellcheck shell=bash
# Copyright (c) 2026 ssch71
# SPDX-License-Identifier: GPL-3.0-or-later
#
# My Fan Cam on SM8250 (Snapdragon 865, Hexagon V66), sourced from rezoss/customize.sh.
#
# - Vendor SNAP: SNPE 2.10.40 runtime, SNAP V4 wrapper (CPU runtime treated as
#   valid, per-model GPU routing, 60 s SNPE watchdog) and the V66 DSP stub/skel.
# - Models: UN1CA Locator v4 + Detection v1, and ReID v21b rebuilt as a GPU-safe
#   A16W8 DLC (fp16-safe virtual keypoints, 4D element-wise ops, no Split).
# - libveframework: the analyzer decoder is created by name as a Codec2 software
#   decoder, because the Android 11 OMX decoders hand MCA blank RGB frames.
# - libauto-reframing: person boxes under 25% of the frame are not tracked.

FC_DIR="$SRC_DIR/platform/$TARGET_PLATFORM/mods/miracle/fancam"

LOG_STEP_IN "- Adding SM8250 My Fan Cam SNAP stack"

for f in \
    "bin/hw/vendor.samsung.hardware.snap-service" \
    "lib/rfsa/adsp/libSnpeDspV66Sk10.so" \
    "lib64/libSNP2.so" \
    "lib64/libSnpeCpu.so" \
    "lib64/libSnpeDspV66Stub.so" \
    "lib64/libSnpeGpu.so" \
    "lib64/libc++_shar10.so" \
    "lib64/libc++_sharsn.so" \
    "lib64/libsnap_vnd2.so" \
    "lib64/libsnpe_dsp_domains_v3.so" \
    "lib64/libsnpe_wrappe2.so" \
    "lib64/vendor.samsung.hardware.hyper-V2-ndk.so" \
    "lib64/vendor.samsung.hardware.snap-V1-ndk.so"; do
    if [[ "$f" == bin/* ]]; then
        [ -f "$WORK_DIR/vendor/$f" ] || { ABORT "Stock vendor SNAP service not found: /vendor/$f"; return 1; }
        # Keep the stock owner, mode and SELinux label of the service.
        ADD_TO_WORK_DIR "$FC_DIR" "vendor" "$f" || exit 1
    else
        ADD_TO_WORK_DIR "$FC_DIR" "vendor" "$f" 0 0 644 "u:object_r:vendor_file:s0" || exit 1
    fi
done

# Retain the non-tracking models and filenames used by the S26 analyzer.
for f in 07-04_Video_HumanPetPose_v3.1.1_SM8850-SNPE238.dlc 07-05_Video_KeywordClassification_v1.1.0_SM8850_SNPE238.dlc; do
    ADD_TO_WORK_DIR "m3qksx" "system" "system/etc/mediacontextanalyzer/$f" 0 0 644 "u:object_r:system_file:s0" || return 1
done

FC_MCA="$FC_DIR/models"
for f in \
    "07-03_Video_HumanPetDetection_UN1CA_Experimental_v1_SM8550-SNPE210_rezoss_custom.dlc" \
    "07-21_Video_ReframingTargetLocator_UN1CA_Experimental_v4_SM8550-SNPE210_rezoss_custom.dlc" \
    "07-22_Video_ReframingReID_UN1CA_Experimental_v21b-gpu_SM8250-SNPE210_rezoss_custom.dlc"; do
    cp "$FC_MCA/$f" "$WORK_DIR/system/system/etc/mediacontextanalyzer/$f" || return 1
    SET_METADATA "system" "system/etc/mediacontextanalyzer/$f" 0 0 644 "u:object_r:system_file:s0"
done
FC_MCA_DIR="$WORK_DIR/system/system/etc/mediacontextanalyzer"
for l in \
    "Pose.dlc:07-04_Video_HumanPetPose_v3.1.1_SM8850-SNPE238.dlc" \
    "Keyword.dlc:07-05_Video_KeywordClassification_v1.1.0_SM8850_SNPE238.dlc" \
    "Detection.dlc:07-03_Video_HumanPetDetection_UN1CA_Experimental_v1_SM8550-SNPE210_rezoss_custom.dlc" \
    "07-03_Video_HumanPetDetection_v2.0.1_SM8850_SNPE238.dlc:Detection.dlc" \
    "Locator.dlc:07-21_Video_ReframingTargetLocator_UN1CA_Experimental_v4_SM8550-SNPE210_rezoss_custom.dlc" \
    "07-21_Video_ReframingTargetLocator_v0.1.0_SM8850-SNPE239.dlc:Locator.dlc" \
    "Reid.dlc:07-22_Video_ReframingReID_UN1CA_Experimental_v21b-gpu_SM8250-SNPE210_rezoss_custom.dlc" \
    "07-22_Video_ReframingReID_v0.2.3_SM8850-SNPE244.dlc:Reid.dlc"; do
    EVAL "ln -sfn \"${l#*:}\" \"$FC_MCA_DIR/${l%%:*}\"" || exit 1
    SET_METADATA "system" "system/etc/mediacontextanalyzer/${l%%:*}" 0 0 644 "u:object_r:system_file:s0"
done

for f in "libveframework.videoeditor.samsung.so" "libauto-reframing-arm64-v8a.so"; do
    [ -f "$WORK_DIR/system/system/lib64/$f" ] || { ABORT "File not found: /system/lib64/$f"; return 1; }
    EVAL "bash \"$FC_DIR/patch_system.sh\" \"$FC_DIR/system_patches.json\" \"$f\" \"$WORK_DIR/system/system/lib64/$f\"" \
        || { ABORT "Failed to patch /system/lib64/$f for My Fan Cam"; return 1; }
done

unset FC_DIR FC_MCA FC_MCA_DIR f l
LOG_STEP_OUT
