# shellcheck disable=SC2034
SKIPUNZIP=1

_ISL_SOURCE="dm3qksx"
if [ "$SOURCE_PLATFORM_SDK_VERSION" -ge 37 ]; then
    _ISL_SOURCE="dm1qksx"
fi
_SYS="$WORK_DIR/system/system"
_LIST="$MODPATH/island_lib.txt"
_BIONIC="libc.so libm.so libdl.so libdl_android.so"

if [ -e "$_SYS/lib/libc.so" ] || [ -L "$_SYS/lib/libc.so" ]; then
    return 0
fi

LOG_STEP_IN "- Installing the ARM32 runtime from $_ISL_SOURCE"
if [ "$SOURCE_PLATFORM_SDK_VERSION" -ge 37 ]; then
    _ISL_FW="$SRC_DIR/prebuilts/samsung/dm1qksx/system"
    [ -s "$SRC_DIR/prebuilts/samsung/dm1qksx/.current" ] || { ABORT "Import the dm1qksx Update prebuilt blobs result before building"; return 1; }
    grep -q "^ro.build.version.sdk=37$" "$_ISL_FW/build.prop" || { ABORT "S23 compatibility firmware must be Android 17"; return 1; }
fi
if [ "$SOURCE_PLATFORM_SDK_VERSION" -ge 37 ]; then
    # Include the complete matching media dependency set, not just graphics HAL
    # dependencies. No ARM32 zygote is started; this serves native processes.
    source "$SRC_DIR/scripts/utils/prebuilt_utils.sh" || return 1
    ADD_PREBUILT_SYSTEM_TREE "$_ISL_SOURCE" "lib" || return 1
fi
if [ "$SOURCE_PLATFORM_SDK_VERSION" -lt 37 ]; then
    while IFS= read -r n; do
        ADD_TO_WORK_DIR "$_ISL_SOURCE" "system" "system/lib/$n"
    done < "$_LIST"
fi
for n in $_BIONIC; do
    [ -L "$_SYS/lib/$n" ] || ADD_TO_WORK_DIR "$_ISL_SOURCE" "system" "system/lib/$n"
done
[ -L "$_SYS/bin/linker" ] || ADD_TO_WORK_DIR "$_ISL_SOURCE" "system" "system/bin/linker"
ADD_TO_WORK_DIR "$_ISL_SOURCE" "system" "system/apex/com.android.runtime.apex"
SET_PROP "vendor" "ro.zygote" "zygote64"
# The imported ARM32 runtime serves vendor processes, not Android apps. Set
# the global app ABIs explicitly so init cannot derive a mixed ABI list from
# the stock odm/vendor props. Keep these in system: stock_props replaces the
# product build.prop later in the platform module sequence.
SET_PROP "system" "ro.product.cpu.abilist" "arm64-v8a"
SET_PROP "system" "ro.product.cpu.abilist32" ""
SET_PROP "system" "ro.product.cpu.abilist64" "arm64-v8a"
LOG_STEP_OUT
unset _ISL_SOURCE _SYS _LIST _BIONIC _ISL_FW n
