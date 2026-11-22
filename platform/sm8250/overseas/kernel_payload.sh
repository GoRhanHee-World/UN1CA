# shellcheck shell=bash
# Sourced by the per-device kernel module before extracting its ZIP.
case ":${TARGET_ASSERT_MODEL:-}:" in
    *:SM-G9810:*|*:SM-G9860:*|*:SM-G9880:*)
        if [ -n "${SM8250_OVERSEAS_KERNEL_ZIP:-}" ]; then
            [ -s "$SM8250_OVERSEAS_KERNEL_ZIP" ] || { ABORT "Overseas kernel ZIP not found: $SM8250_OVERSEAS_KERNEL_ZIP"; return 1; }
            cp "$SM8250_OVERSEAS_KERNEL_ZIP" "$KERNEL_TMP/kernel.zip" || return 1
        else
            DOWNLOAD_FILE "https://github.com/GoRhanHee-World/android_samsung_kernel_sm8250/releases/download/$KERNEL_TAG/$KERNEL_ZIP" \
                "$KERNEL_TMP/kernel.zip" || return 1
        fi
        bash "$SRC_DIR/platform/sm8250/overseas/verify_kernel.sh" \
            "$KERNEL_TMP/kernel.zip" "$TARGET_CODENAME" || return 1
        ;;
    *)
        DOWNLOAD_FILE "https://github.com/GoRhanHee-World/android_samsung_kernel_sm8250/releases/download/$KERNEL_TAG/$KERNEL_ZIP" \
            "$KERNEL_TMP/kernel.zip" || return 1
        ;;
esac
