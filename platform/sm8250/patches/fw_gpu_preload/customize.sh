SKIPUNZIP=1

LOG_STEP_IN "- GPU drivers: allow the stock SM8250 driver packages to preload (05cf5f3)"
_VP="$WORK_DIR/vendor/build.prop"
[ -f "$_VP" ] || ABORT "[$TARGET_CODENAME] GPU preload: no vendor/build.prop in work_dir"
for _KV in "ro.gfx.driver.0=com.samsung.gamedriver.sm8250" \
           "ro.gfx.driver.1=com.qualcomm.qti.gpudrivers.kona.api30" \
           "graphics.gpu.profiler.vulkan_layer_apk=com.samsung.vklayer.sm8250"; do
    grep -qxF "$_KV" "$_VP" || ABORT "[$TARGET_CODENAME] GPU preload: vendor/build.prop no longer has $_KV - re-read the vendor before allowing it"
done

ADD_TO_WORK_DIR "$MODPATH" "system" "system/etc/sysconfig/minsos-gpu-preload.xml" 0 0 644 "u:object_r:system_file:s0"

cmp -s "$MODPATH/system/etc/sysconfig/minsos-gpu-preload.xml" "$WORK_DIR/system/system/etc/sysconfig/minsos-gpu-preload.xml" \
    || ABORT "[$TARGET_CODENAME] GPU preload: system/etc/sysconfig/minsos-gpu-preload.xml did not land in work_dir"
grep -q '^system/etc/sysconfig/minsos-gpu-preload.xml 0 0 644 ' "$WORK_DIR/configs/fs_config-system" \
    || ABORT "[$TARGET_CODENAME] GPU preload: minsos-gpu-preload.xml has no 0 0 644 fs_config entry"
grep -q '^/system/etc/sysconfig/minsos-gpu-preload.* u:object_r:system_file:s0$' "$WORK_DIR/configs/file_context-system" \
    || ABORT "[$TARGET_CODENAME] GPU preload: minsos-gpu-preload.xml has no system_file label"
LOG "- 3 SM8250 GPU packages allowed (gamedriver, kona prerelease driver, vklayer)"
unset _VP _KV
LOG_STEP_OUT
