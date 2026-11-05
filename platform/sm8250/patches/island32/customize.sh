SKIPUNZIP=1

_ISL_FW="SM-S918B/EUX"
_ISL_DIR="$FW_DIR/SM-S918B_EUX"
_ISL_PIN="S918BXXUAGZIF/S918BOXMAGZIF/S918BXXUAGZIF"
_ISL_RUNTIME_SHA="cd2f0aea718209191add1af49a627b31f12b8f59a850403ec00e85c19fc1b412"
_SYS="$WORK_DIR/system/system"
_LIST="$MODPATH/island_lib.txt"
_BIONIC="libc.so libm.so libdl.so libdl_android.so"

if [ -e "$_SYS/lib/libc.so" ] || [ -L "$_SYS/lib/libc.so" ]; then
    LOG "- The donor already provides a 32-bit runtime"
    return 0
fi

[ -f "$_ISL_DIR/.extracted" ] \
    || ABORT "[$TARGET_CODENAME] island32: the island source $_ISL_FW is not extracted (out/fw/SM-S918B_EUX)"
[ "$(cat "$_ISL_DIR/.extracted")" = "$_ISL_PIN" ] \
    || ABORT "[$TARGET_CODENAME] island32: island source is $(cat "$_ISL_DIR/.extracted"), measured was $_ISL_PIN"
[ "$(wc -l < "$_LIST")" = "43" ] || ABORT "[$TARGET_CODENAME] island32: island_lib.txt is not the 43-file list"

LOG_STEP_IN "- 32-bit island from $_ISL_FW"
while read -r n s; do
    [ -f "$_SYS/lib/$n" ] && [ "$(sha256sum "$_SYS/lib/$n" | cut -d' ' -f1)" = "$s" ] && continue
    ADD_TO_WORK_DIR "$_ISL_FW" "system" "system/lib/$n"
done < "$_LIST"
for n in $_BIONIC; do
    [ -L "$_SYS/lib/$n" ] || ADD_TO_WORK_DIR "$_ISL_FW" "system" "system/lib/$n"
done
[ -L "$_SYS/bin/linker" ] || ADD_TO_WORK_DIR "$_ISL_FW" "system" "system/bin/linker"
_RT="$_SYS/apex/com.android.runtime.apex"
[ -f "$_RT" ] || ABORT "[$TARGET_CODENAME] island32: the donor has no system/apex/com.android.runtime.apex - the APEX layout moved, re-measure"
[ "$(sha256sum "$_RT" | cut -d' ' -f1)" = "$_ISL_RUNTIME_SHA" ] \
    || ADD_TO_WORK_DIR "$_ISL_FW" "system" "system/apex/com.android.runtime.apex"
SET_PROP "vendor" "ro.zygote" "zygote64"
SET_PROP "product" "ro.product.product.cpu.abilist" "arm64-v8a"
SET_PROP "product" "ro.product.product.cpu.abilist64" "arm64-v8a"
LOG_STEP_OUT

_FS="$WORK_DIR/configs/fs_config-system"
_FC="$WORK_DIR/configs/file_context-system"
while read -r n s; do
    [ "$(sha256sum "$_SYS/lib/$n" 2> /dev/null | cut -d' ' -f1)" = "$s" ] \
        || ABORT "[$TARGET_CODENAME] island32: system/lib/$n is missing or not the measured island file"
    grep -q -F "system/lib/$n " "$_FS" || ABORT "[$TARGET_CODENAME] island32: no fs_config entry for system/lib/$n"
    grep -q -F "/system/lib/$(_HANDLE_SPECIAL_CHARS "$n") u:object_r:system_lib_file:s0" "$_FC" \
        || ABORT "[$TARGET_CODENAME] island32: system/lib/$n would not be labeled system_lib_file"
done < "$_LIST"
for n in $_BIONIC; do
    [ "$(readlink "$_SYS/lib/$n")" = "/apex/com.android.runtime/lib/bionic/$n" ] \
        || ABORT "[$TARGET_CODENAME] island32: system/lib/$n does not point into the runtime APEX"
    grep -q -F "system/lib/$n " "$_FS" || ABORT "[$TARGET_CODENAME] island32: no fs_config entry for system/lib/$n"
done
[ "$(readlink "$_SYS/bin/linker")" = "/apex/com.android.runtime/bin/linker" ] \
    || ABORT "[$TARGET_CODENAME] island32: system/bin/linker does not point to the runtime APEX's 32-bit linker"
grep -q -F "/system/bin/linker u:object_r:system_linker_exec:s0" "$_FC" \
    || ABORT "[$TARGET_CODENAME] island32: system/bin/linker would not be labeled system_linker_exec"
[ "$(sha256sum "$_RT" | cut -d' ' -f1)" = "$_ISL_RUNTIME_SHA" ] \
    || ABORT "[$TARGET_CODENAME] island32: the runtime APEX is not the island source's hybrid one"
_EXTRA="$(cd "$_SYS/lib" && for n in *; do case " $_BIONIC modules " in *" $n "*) continue ;; esac; grep -q "^$n " "$_LIST" || echo "$n"; done)"
[ -z "$_EXTRA" ] || ABORT "[$TARGET_CODENAME] island32: system/lib holds more than the island: $(echo $_EXTRA | cut -c1-200)"
grep -h "^ro.zygote=" "$WORK_DIR/vendor/default.prop" "$WORK_DIR/vendor/build.prop" 2> /dev/null | grep -q -v "^ro.zygote=zygote64$" \
    && ABORT "[$TARGET_CODENAME] island32: vendor still has a ro.zygote other than zygote64"
grep -q "^ro.zygote=zygote64$" "$WORK_DIR/vendor/default.prop" "$WORK_DIR/vendor/build.prop" 2> /dev/null \
    || ABORT "[$TARGET_CODENAME] island32: ro.zygote=zygote64 did not land in vendor"
grep -q "^ro.product.product.cpu.abilist64=arm64-v8a$" "$WORK_DIR/product/etc/build.prop" \
    || ABORT "[$TARGET_CODENAME] island32: product abilist64 did not land"
grep -q "^ro.product.product.cpu.abilist32=" "$WORK_DIR/product/etc/build.prop" \
    && ABORT "[$TARGET_CODENAME] island32: product defines abilist32, init would take it"
for p in bin/app_process32 etc/init/hw/init.zygote64_32.rc; do
    [ -e "$_SYS/$p" ] && ABORT "[$TARGET_CODENAME] island32: $p is still there"
done
LOG "- Island in: $(wc -l < "$_LIST") libs + 5 links + runtime APEX ${_ISL_RUNTIME_SHA:0:12} (64-bit-only donor)"
