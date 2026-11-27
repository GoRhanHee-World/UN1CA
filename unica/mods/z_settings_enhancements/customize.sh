# shellcheck shell=bash
# shellcheck disable=SC2016
# Apply after settings (and monotype), without an APK or an Xposed runtime.
DECODE_APK "system" "system/priv-app/SecSettings/SecSettings.apk" || return 1

APPLY_PATCH "system" "system/priv-app/SecSettings/SecSettings.apk" \
    "$MODPATH/SecSettings.apk/0001-Introduce-SettingsEnhancements.patch" || return 1

# Preference.mItemView is assigned after stock text, click and accessibility
# binding. Do not touch the stock Preference data or controllers.
SMALI_PATCH "system" "system/priv-app/SecSettings/SecSettings.apk" \
    "smali/androidx/preference/Preference.smali" "replace" \
    'onBindViewHolder(Landroidx/preference/PreferenceViewHolder;)V' \
    'iput-object v0, p0, Landroidx/preference/Preference;->mItemView:Landroid/view/View;' \
    '    iput-object v0, p0, Landroidx/preference/Preference;->mItemView:Landroid/view/View;\n\n    invoke-static {p0, v0}, Lio/mesalabs/unica/settings/enhancements/Bindings;->bind(Landroidx/preference/Preference;Landroid/view/View;)V' \
    > /dev/null || return 1

# Rebind visible rows on returning from the editor, after stock controllers have
# refreshed their values. This also picks up wallpaper and palette changes.
SMALI_PATCH "system" "system/priv-app/SecSettings/SecSettings.apk" \
    "smali/com/android/settings/dashboard/DashboardFragment.smali" "replace" \
    'onResume()V' \
    'invoke-virtual {p0}, Lcom/android/settings/dashboard/DashboardFragment;->updatePreferenceStates()V' \
    '    invoke-virtual {p0}, Lcom/android/settings/dashboard/DashboardFragment;->updatePreferenceStates()V\n\n    invoke-static {p0}, Lio/mesalabs/unica/settings/enhancements/Bindings;->refresh(Landroidx/preference/PreferenceFragmentCompat;)V' \
    > /dev/null || return 1

# About phone uses its own chart, rather than Preference summaries. Run after
# its copy listener and content description have been assigned as well.
SMALI_PATCH "system" "system/priv-app/SecSettings/SecSettings.apk" \
    "smali_classes3/com/samsung/android/settings/deviceinfo/aboutphone/DeviceInfoHeader.smali" "replace" \
    'getDeviceInfoView(ILcom/samsung/android/settings/deviceinfo/aboutphone/DeviceInfoHeader$DeviceInfo;)Landroid/view/ViewGroup;' \
    'return-object p1' \
    '    invoke-static {p1, v2}, Lio/mesalabs/unica/settings/enhancements/Bindings;->aboutRow(Landroid/view/View;Ljava/lang/String;)V\n\n    return-object p1' \
    > /dev/null || return 1

# Rebuild the About phone chart when returning from the editor, so product-name
# changes and turning privacy off do not leave the previous display in place.
SMALI_PATCH "system" "system/priv-app/SecSettings/SecSettings.apk" \
    "smali_classes3/com/samsung/android/settings/deviceinfo/aboutphone/DeviceInfoHeaderPreferenceController.smali" "replace" \
    'onResume()V' \
    'iget-object v0, p0, Lcom/samsung/android/settings/deviceinfo/aboutphone/DeviceInfoHeaderPreferenceController;->mActivity:Landroid/app/Activity;' \
    '    iget-object v0, p0, Lcom/samsung/android/settings/deviceinfo/aboutphone/DeviceInfoHeaderPreferenceController;->mDeviceInfoHeader:Lcom/samsung/android/settings/deviceinfo/aboutphone/DeviceInfoHeader;\n\n    if-eqz v0, :unica_refresh_header_done\n\n    invoke-virtual {v0}, Lcom/samsung/android/settings/deviceinfo/aboutphone/DeviceInfoHeader;->initInfoChart()V\n\n    :unica_refresh_header_done\n    iget-object v0, p0, Lcom/samsung/android/settings/deviceinfo/aboutphone/DeviceInfoHeaderPreferenceController;->mActivity:Landroid/app/Activity;' \
    > /dev/null || return 1

# Keep real battery readers and their unavailable-data handling. Only remove
# the regional/authentication gate hiding the existing regulatory rows.
SMALI_PATCH "system" "system/priv-app/SecSettings/SecSettings.apk" \
    "smali_classes3/com/samsung/android/settings/deviceinfo/batteryinfo/BatteryInfoUtils.smali" "return" \
    'isAvailableBatteryRegulatory(Landroid/content/Context;)Z' 'true' \
    > /dev/null || return 1

ENHANCE_APK="$APKTOOL_DIR/system/priv-app/SecSettings/SecSettings.apk"

# Add views without replacing the original software information rows. In
# particular, the original build-number controller still enables developer mode.
sed -i '/xmlns:android=.*xmlns:settings=.*>/a\    <io.mesalabs.unica.settings.enhancements.SoftwareCardPreference android:key="unica_software_card" android:order="-1000000" android:selectable="false" />' \
    "$ENHANCE_APK/res/xml/sec_software_info_settings.xml" || return 1
sed -i '/<\/PreferenceScreen>/i\    <Preference android:title="@string/unica_enhance_title" android:summary="@string/unica_enhance_summary" android:key="unica_settings_enhancements"><intent android:targetPackage="com.android.settings" android:targetClass="io.mesalabs.unica.settings.enhancements.AppearanceActivity" /></Preference>' \
    "$ENHANCE_APK/res/xml/unica_top_settings.xml" || return 1
sed -i '/<\/PreferenceScreen>/i\    <com.android.settings.widget.HomepagePreference android:icon="@drawable/unica_enhance_bluetooth" android:title="@string/bluetooth_settings_title" android:key="top_level_unica_bluetooth" android:order="-495000" settings:controller="io.mesalabs.unica.settings.enhancements.BluetoothShortcutController"><intent android:action="android.settings.BLUETOOTH_SETTINGS" /></com.android.settings.widget.HomepagePreference>' \
    "$ENHANCE_APK/res/xml/sec_top_level_settings.xml" || return 1

sed -i '/<\/application>/i\        <activity android:name="io.mesalabs.unica.settings.enhancements.AppearanceActivity" android:exported="false" android:label="@string/unica_enhance_title" android:theme="@android:style/Theme.DeviceDefault.Settings" />' \
    "$ENHANCE_APK/AndroidManifest.xml" || return 1
for ENHANCE_PERMISSION in CHANGE_COMPONENT_ENABLED_STATE READ_WALLPAPER_INTERNAL; do
    if ! grep -qF "android.permission.$ENHANCE_PERMISSION\"" "$ENHANCE_APK/AndroidManifest.xml"; then
        sed -i "/<application/i\\    <uses-permission android:name=\"android.permission.$ENHANCE_PERMISSION\" />" \
            "$ENHANCE_APK/AndroidManifest.xml" || return 1
    fi
done
unset ENHANCE_APK ENHANCE_PERMISSION
