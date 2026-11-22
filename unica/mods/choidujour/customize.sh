# shellcheck disable=SC2034
SKIPUNZIP=1

if ! ${ROM_OTA_ENABLED:-false} && ! $ROM_IS_OFFICIAL; then
    LOG "- OTA updates disabled. Skipping"
    return 0
fi

if [ ! -s "$SRC_DIR/security/unica_ota.x509.pem" ] || [ ! -s "$SRC_DIR/security/unica_ota.pk8" ]; then
    ABORT "OTA updates require security/unica_ota.{x509.pem,pk8}; run scripts/generate_ota_key.sh --help"
    return 1
fi

ADD_TO_WORK_DIR "$MODPATH" "system" "." 0 0 755 "u:object_r:system_file:s0"

# Rebuild with the same platform certificate as Settings (shared android.uid.system).
DECODE_APK "system" "system/priv-app/ChoiDujour/ChoiDujour.apk"
if [ -n "${ROM_OTA_URL:-}" ]; then
    SET_PROP "system" "ro.unica.ota_url" "$ROM_OTA_URL"
    EVAL "echo \"ro.unica.ota_url u:object_r:build_prop:s0 exact string\" >> \"$WORK_DIR/system/system/etc/selinux/plat_property_contexts\""
    APPLY_PATCH "system" "system/priv-app/ChoiDujour/ChoiDujour.apk" \
        "$MODPATH/ChoiDujour.apk/0001-Use-build-OTA-manifest.patch"
fi
APPLY_PATCH "system" "system/priv-app/ChoiDujour/ChoiDujour.apk" \
    "$MODPATH/ChoiDujour.apk/0002-Use-identity-encoding-for-download-size-checks.patch"

LOG "- Patching /system/system/etc/security/otacerts.zip"
EVAL "rm \"$WORK_DIR/system/system/etc/security/otacerts.zip\""
EVAL "zip -q -j \"$WORK_DIR/system/system/etc/security/otacerts.zip\" \"$SRC_DIR/security/unica_ota.x509.pem\"" || return 1

DECODE_APK "system" "system/priv-app/SecSettings/SecSettings.apk"

# The One UI 9 donor moved this activity from classes2.dex to classes.dex.
# shellcheck disable=SC2016
FOTA_SMALI="$(find "$APKTOOL_DIR/system/priv-app/SecSettings/SecSettings.apk" -name 'Settings$FOTASuggestionActivity.smali' -print -quit)"
[ -n "$FOTA_SMALI" ] || { ABORT "FOTA suggestion activity not found"; return 1; }
FOTA_DEX="${FOTA_SMALI%/com/android/settings/*}"
EVAL "git apply -p2 --unsafe-paths --directory=\"$FOTA_DEX\" \"$MODPATH/suggestions/SecSettings.apk/0001-Launch-UN1CA-Updates-from-suggestions.patch\"" || return 1
# The replacement uses v0-v3; old donors only reserved v0.
sed -i '/^\.method .* onCreate(/,/^\.end method/s/    \.locals [0-9]*/    .locals 4/' "$FOTA_SMALI"
unset FOTA_SMALI FOTA_DEX

# Disable stock OTA references
if [ "$SOURCE_PLATFORM_SDK_VERSION" -ge "37" ]; then
    SMALI_PATCH "system" "system/priv-app/SecSettings/SecSettings.apk" \
        "smali_classes3/com/samsung/android/settings/homepage/TopLevelSoftwareUpdatePreferenceController.smali" "return" \
        'getAvailabilityStatus()I' '3'
else
    SMALI_PATCH "system" "system/priv-app/SecSettings/SecSettings.apk" \
        "smali_classes3/com/samsung/android/settings/softwareupdate/SoftwareUpdateUtils.smali" "return" \
        "isOTAUpgradeAllowed(Landroid/content/Context;)Z" "false"
fi

# Dynamically patch SecSettings
# - Add missing/non-xml files in place
# - Patch existing files
#   - Use the first line of the file to tell sed how to apply the rest of the content
#   - Exception made for files under *res/values* where the "resources" tag gets nuked
while IFS= read -r f; do
    f="${f//$MODPATH\/SecSettings.apk\//}"

    if [ ! -f "$APKTOOL_DIR/system/priv-app/SecSettings/SecSettings.apk/$f" ] || \
            [[ "$f" != *".xml" ]]; then
        LOG "- Adding \"$f\" to /system/system/priv-app/SecSettings.apk"
        EVAL "mkdir -p \"$(dirname "$APKTOOL_DIR/system/priv-app/SecSettings/SecSettings.apk/$f")\""
        EVAL "cp -a \"$MODPATH/SecSettings.apk/${f//\$/\\$}\" \"$APKTOOL_DIR/system/priv-app/SecSettings/SecSettings.apk/${f//\$/\\$}\""
    else
        LOG "- Patching \"$f\" in /system/system/priv-app/SecSettings.apk"
        if [[ "$f" == *"res/values"* ]]; then
            PATCH_INST="/<\/resources>/i"
            CONTENT="$(sed -e "/?xml/d" -e "/resources>/d" "$MODPATH/SecSettings.apk/$f")"
        else
            PATCH_INST="$(head -n 1 "$MODPATH/SecSettings.apk/$f")"
            CONTENT="$(tail -n +2 "$MODPATH/SecSettings.apk/$f")"
        fi
        CONTENT="$(sed -e "s/\"/\\\\\"/g" -e "s/\\$/\\\\$/g" -e "s/ /\\\ /g" -e "s/\\\\n/\\\\\\\\\n/g" <<< "$CONTENT")"
        CONTENT="$(sed -E ':a;N;$!ba;s/\r{0,1}\n/\\n/g' <<< "$CONTENT")"
        EVAL "sed -i \"$PATCH_INST $CONTENT\" \"$APKTOOL_DIR/system/priv-app/SecSettings/SecSettings.apk/$f\""
    fi
done < <(find "$MODPATH/SecSettings.apk" -type f)

# Keep this controller out of Samsung's nearly full dex files.
CHOIDUJOUR_DEX=5
while [ -d "$APKTOOL_DIR/system/priv-app/SecSettings/SecSettings.apk/smali_classes$CHOIDUJOUR_DEX" ]; do
    CHOIDUJOUR_DEX=$((CHOIDUJOUR_DEX + 1))
done
mkdir -p "$APKTOOL_DIR/system/priv-app/SecSettings/SecSettings.apk/smali_classes$CHOIDUJOUR_DEX/io/mesalabs/unica/settings"
mv "$APKTOOL_DIR/system/priv-app/SecSettings/SecSettings.apk/smali_classes4/io/mesalabs/unica/settings/ChoiDujourPreferenceController.smali" \
    "$APKTOOL_DIR/system/priv-app/SecSettings/SecSettings.apk/smali_classes$CHOIDUJOUR_DEX/io/mesalabs/unica/settings/"
unset CHOIDUJOUR_DEX

unset PATCH_INST CONTENT
