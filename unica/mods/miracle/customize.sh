# shellcheck disable=SC2034
SKIPUNZIP=1

LOG_STEP_IN "- Adding Galaxy S26 apps and media backend"
while IFS= read -r AI_FILE; do
    if [[ "$AI_FILE" == *.apk ]] && [ -d "$WORK_DIR/system/${AI_FILE%/*}" ]; then
        DELETE_FROM_WORK_DIR "system" "${AI_FILE%/*}"
    fi
    AI_LABEL="u:object_r:system_file:s0"
    [[ "$AI_FILE" == system/lib64/* ]] && AI_LABEL="u:object_r:system_lib_file:s0"
    ADD_TO_WORK_DIR "m3qksx" "system" "$AI_FILE" 0 0 644 "$AI_LABEL"
    if [[ "$AI_FILE" == *.apk ]]; then
        SET_METADATA "system" "${AI_FILE%/*}" 0 0 755 "u:object_r:system_file:s0"
    fi
done < "$MODPATH/files.list"
unset AI_FILE AI_LABEL
for AI_DIR in PhotoEditor_Full SemanticSearchCore SamsungCoreServices-Stub; do
    if [ -d "$WORK_DIR/system/system/priv-app/$AI_DIR" ]; then
        DELETE_FROM_WORK_DIR "system" "system/priv-app/$AI_DIR"
    fi
done
unset AI_DIR
LOG_STEP_OUT

if [ ! "$(GET_PROP "system" "ro.unica.codename")" ]; then
    EVAL "echo \"ro.unica.codename u:object_r:build_prop:s0 exact string\" >> \"$WORK_DIR/system/system/etc/selinux/plat_property_contexts\""
    SET_PROP "system" "ro.unica.codename" "Miracle"
fi

# Keep the Android 17 donor's framework implementation of adaptive colour tone.
LOG "- Using Galaxy S26 Adaptive colour tone app with the source framework"

# The S26 analyzer models target SM8850. Retain the port's GPU backend.
# Media Context Analyzer
LOG_STEP_IN "- Adding Media Context Analyzer feature"
ADD_TO_WORK_DIR "a56xnaxx" "system" "system/etc/mediacontextanalyzer/Detection.tflite" 0 0 644 "u:object_r:system_file:s0"
ADD_TO_WORK_DIR "a56xnaxx" "system" "system/etc/mediacontextanalyzer/human-pet-det_SR-V131.tflite" 0 0 644 "u:object_r:system_file:s0"
ADD_TO_WORK_DIR "a56xnaxx" "system" "system/etc/mediacontextanalyzer/human-pet-pose_SR-V200.tflite" 0 0 644 "u:object_r:system_file:s0"
ADD_TO_WORK_DIR "a56xnaxx" "system" "system/etc/mediacontextanalyzer/Keyword.tflite" 0 0 644 "u:object_r:system_file:s0"
ADD_TO_WORK_DIR "a56xnaxx" "system" "system/etc/mediacontextanalyzer/keyword-classification_SR-V031.tflite" 0 0 644 "u:object_r:system_file:s0"
EVAL "ln -s \"human-pet-pose_SR-V200.tflite\" \"$WORK_DIR/system/system/etc/mediacontextanalyzer/Pose.tflite\""
SET_METADATA "system" "system/etc/mediacontextanalyzer/Pose.tflite" 0 0 644 "u:object_r:system_file:s0"
ADD_TO_WORK_DIR "a56xnaxx" "system" "system/lib64/libcontextanalyzer_jni.media.samsung.so" 0 0 644 "u:object_r:system_lib_file:s0"
ADD_TO_WORK_DIR "a56xnaxx" "system" "system/lib64/libmediacontextanalyzer.so" 0 0 644 "u:object_r:system_lib_file:s0"
ADD_TO_WORK_DIR "a56xnaxx" "system" "system/lib64/libvideo-highlight-arm64-v8a.so" 0 0 644 "u:object_r:system_lib_file:s0"
SET_FLOATING_FEATURE_CONFIG "SEC_FLOATING_FEATURE_MMFW_CONFIG_MEDIA_CONTEXT_ANALYZER_CORE" "GPU"
SET_FLOATING_FEATURE_CONFIG "SEC_FLOATING_FEATURE_MMFW_SUPPORT_MEDIA_CONTEXT_ANALYZER" "TRUE"
LOG_STEP_OUT

# Apply platform adaptations after the common S26 files have been installed.
if [ -f "$SRC_DIR/platform/$TARGET_PLATFORM/mods/miracle/customize.sh" ]; then
    source "$SRC_DIR/platform/$TARGET_PLATFORM/mods/miracle/customize.sh" || return 1
fi

SET_FLOATING_FEATURE_CONFIG "SEC_FLOATING_FEATURE_COMMON_CONFIG_AI_VERSION" "20263"
SET_FLOATING_FEATURE_CONFIG "SEC_FLOATING_FEATURE_FRAMEWORK_CONFIG_NOW_NUDGE_VERSION" "2"
SET_FLOATING_FEATURE_CONFIG "SEC_FLOATING_FEATURE_MMFW_SUPPORT_TARGET_TRACKING" "TRUE"
SET_FLOATING_FEATURE_CONFIG "SEC_FLOATING_FEATURE_AUDIO_CONFIG_MULTISOURCE_SEPARATOR" "{FastScanning_6, SourceSeparator_4, Version_1.3.0}"
SET_FLOATING_FEATURE_CONFIG "SEC_FLOATING_FEATURE_FRAMEWORK_SUPPORT_PERSONALIZED_DATA_CORE" "TRUE"
SET_FLOATING_FEATURE_CONFIG "SEC_FLOATING_FEATURE_MSCH_SUPPORT_NLSEARCH" "TRUE"
DECODE_APK "system" "system/priv-app/SamsungSmartSuggestions/SamsungSmartSuggestions.apk"

# Keep the Game Booster app paired with the donor's framework.
ADD_TO_WORK_DIR "$SOURCE_FIRMWARE" "system" \
    "system/priv-app/GameTools_Dream/GameTools_Dream.apk" 0 0 644 "u:object_r:system_file:s0"

LOG_STEP_IN "- Adding Galaxy S26 CPU Pet Detector models"
if [ -d "$WORK_DIR/vendor/etc/petdetector/studio_pd" ]; then
    DELETE_FROM_WORK_DIR "vendor" "etc/petdetector/studio_pd"
fi
for PET_FILE in config_thresholds.json studio_pd_cnn.info studio_pd_cnn.tflite; do
    ADD_TO_WORK_DIR "m3qksx" "vendor" "etc/petdetector/studio_pd/$PET_FILE" 0 0 644 "u:object_r:vendor_configs_file:s0"
done
unset PET_FILE
LOG_STEP_OUT

source "$MODPATH/sounds.sh"
