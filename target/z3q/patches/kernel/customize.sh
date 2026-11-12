KERNEL_BASE_TAG="boot-z3q-20261101-212207"
KERNEL_TAG="z3q-20261112"
KERNEL_ZIP="not-stock-20261112-c222db3e-z3q.zip"

LOG_STEP_IN "- Repacking not_kernel ($KERNEL_TAG)"
mkdir -p "$TMP_DIR" "$WORK_DIR/kernel"
KERNEL_TMP="$(mktemp -d "$TMP_DIR/kernel-z3q.XXXXXX")"

# Preserve the boot header and ramdisk already used by this ROM.
DOWNLOAD_FILE "https://github.com/ssch71/not_samsung.sm8250-4.19/releases/download/$KERNEL_BASE_TAG/boot.img" "$KERNEL_TMP/boot.img"
DOWNLOAD_FILE "https://github.com/GoRhanHee-World/android_samsung_kernel_sm8250/releases/download/$KERNEL_TAG/$KERNEL_ZIP" "$KERNEL_TMP/kernel.zip"

LOG "- Extracting the boot image"
EVAL "unpack_bootimg --boot_img \"$KERNEL_TMP/boot.img\" --out \"$KERNEL_TMP/out\" --format mkbootimg -0 > \"$KERNEL_TMP/mkbootimg.args\"" || return 1
KERNEL_ARGS=()
while IFS= read -r -d '' KERNEL_ARG; do
    KERNEL_ARGS+=("$KERNEL_ARG")
done < "$KERNEL_TMP/mkbootimg.args"
if [ ! -s "$KERNEL_TMP/out/kernel" ] || [ ! -s "$KERNEL_TMP/out/dtb" ]; then
    ABORT "Failed to extract the kernel and DTB from boot.img"
fi

LOG "- Replacing the kernel, DTB and DTBO from $KERNEL_ZIP"
EVAL "unzip -p \"$KERNEL_TMP/kernel.zip\" Image > \"$KERNEL_TMP/out/kernel\"" || return 1
EVAL "unzip -p \"$KERNEL_TMP/kernel.zip\" dtb > \"$KERNEL_TMP/out/dtb\"" || return 1
EVAL "unzip -p \"$KERNEL_TMP/kernel.zip\" dtbo.img > \"$KERNEL_TMP/dtbo.img\"" || return 1
for IMG in out/kernel out/dtb dtbo.img; do
    if [ ! -s "$KERNEL_TMP/$IMG" ]; then
        ABORT "Missing or empty kernel payload: $IMG"
    fi
done

LOG "- Repacking boot.img"
printf -v KERNEL_COMMAND '%q ' mkbootimg "${KERNEL_ARGS[@]}" -o "$KERNEL_TMP/new-boot.img"
EVAL "$KERNEL_COMMAND" || return 1
echo -n "SEANDROIDENFORCE" >> "$KERNEL_TMP/new-boot.img"
if [ "$(wc -c < "$KERNEL_TMP/new-boot.img")" -gt "$TARGET_BOOT_PARTITION_SIZE" ]; then
    ABORT "boot.img exceeds the target boot partition size"
fi
if [ "$(wc -c < "$KERNEL_TMP/dtbo.img")" -gt "$TARGET_DTBO_PARTITION_SIZE" ]; then
    ABORT "dtbo.img exceeds the target DTBO partition size"
fi
EVAL "mv -f \"$KERNEL_TMP/new-boot.img\" \"$WORK_DIR/kernel/boot.img\"" || return 1
EVAL "mv -f \"$KERNEL_TMP/dtbo.img\" \"$WORK_DIR/kernel/dtbo.img\"" || return 1
EVAL "rm -rf \"$KERNEL_TMP\""

unset KERNEL_BASE_TAG KERNEL_TAG KERNEL_ZIP KERNEL_TMP
unset KERNEL_ARGS KERNEL_ARG KERNEL_COMMAND IMG
LOG_STEP_OUT
