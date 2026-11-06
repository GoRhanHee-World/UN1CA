# shellcheck disable=SC2034
SKIPUNZIP=1

_ISL_SOURCE="dm3qksx"
_SYS="$WORK_DIR/system/system"
_LIST="$MODPATH/island_lib.txt"
_BIONIC="libc.so libm.so libdl.so libdl_android.so"

if [ -e "$_SYS/lib/libc.so" ] || [ -L "$_SYS/lib/libc.so" ]; then
    return 0
fi

LOG_STEP_IN "- 32-bit runtime from prebuilts/samsung/$_ISL_SOURCE"
while IFS= read -r n; do
    ADD_TO_WORK_DIR "$_ISL_SOURCE" "system" "system/lib/$n"
done < "$_LIST"
for n in $_BIONIC; do
    [ -L "$_SYS/lib/$n" ] || ADD_TO_WORK_DIR "$_ISL_SOURCE" "system" "system/lib/$n"
done
[ -L "$_SYS/bin/linker" ] || ADD_TO_WORK_DIR "$_ISL_SOURCE" "system" "system/bin/linker"
ADD_TO_WORK_DIR "$_ISL_SOURCE" "system" "system/apex/com.android.runtime.apex"
SET_PROP "vendor" "ro.zygote" "zygote64"
SET_PROP "product" "ro.product.product.cpu.abilist" "arm64-v8a"
SET_PROP "product" "ro.product.product.cpu.abilist64" "arm64-v8a"
LOG_STEP_OUT
unset _ISL_SOURCE _SYS _LIST _BIONIC n
