if [ "$SOURCE_PLATFORM_SDK_VERSION" -ge 37 ]; then
    APPLY_PATCH "system" "system/priv-app/CIDManager/CIDManager.apk" \
        "$MODPATH/0001-Support-CID-activation-without-VaultKeeper.patch"
fi
