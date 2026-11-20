# shellcheck shell=bash
LOG_STEP_IN "- Matching SketchBook's native registration to its bundled Java SDK"
DECODE_APK "system" "system/app/SketchBook/SketchBook.apk" || return 1
source "$SRC_DIR/platform/$TARGET_PLATFORM/mods/miracle/sketchbook.sh" || return 1
LOG_STEP_OUT

LOG_STEP_IN "- Pairing the S26 analyzer with the SM8250 SNAP backend"
for MCA_LIB in libmediacontextanalyzer.so libcontextanalyzer_jni.media.samsung.so libauto-reframing-arm64-v8a.so libvideo-highlight-arm64-v8a.so; do
    ADD_TO_WORK_DIR "m3qksx" "system" "system/lib64/$MCA_LIB" 0 0 644 "u:object_r:system_lib_file:s0" || return 1
done
unset MCA_LIB
LOG_STEP_OUT
source "$SRC_DIR/platform/$TARGET_PLATFORM/mods/miracle/fancam/apply.sh" || return 1
source "$SRC_DIR/platform/$TARGET_PLATFORM/mods/miracle/photo_editor.sh" || return 1
