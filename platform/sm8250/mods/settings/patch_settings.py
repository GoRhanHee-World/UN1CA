#!/usr/bin/env python3
"""Install the standalone MinsOS-derived report collector in decoded Settings."""

from pathlib import Path
import re
import shutil
import sys
import xml.etree.ElementTree as ET

ANDROID = "{http://schemas.android.com/apk/res/android}"
ACTIVITY = "io.mesalabs.unica.reports.BugReport"
THEME = "Theme.Settings.RoutineActionActivity"
PACKAGE = Path("io/mesalabs/unica/reports")


def install(apk: Path) -> None:
    source = Path(__file__).resolve().parent
    manifest = apk / "AndroidManifest.xml"
    page = apk / "res/xml/unica_top_settings.xml"
    for path in (manifest, page):
        if not path.is_file():
            raise ValueError(f"Missing Settings input: {path}")

    # Validate all inputs before changing the decoded APK.
    root = ET.parse(manifest).getroot()
    app = root.find("application")
    if app is None or root.get("package") != "com.android.settings":
        raise ValueError("Expected the Samsung Settings manifest")
    ET.parse(page)
    styles = [node.get("name") for path in (apk / "res/values").glob("*.xml")
              for node in ET.parse(path).getroot() if node.tag == "style"]
    if THEME not in styles:
        raise ValueError(f"Missing stock report dialog theme: {THEME}")
    resources = []
    for path in sorted((source / "res").glob("*/unica_bugreport_strings.xml")):
        entries = list(ET.parse(path).getroot())
        directory = apk / "res" / path.parent.name
        names = {node.get("name") for file in directory.glob("*.xml")
                 for node in ET.parse(file).getroot()}
        dest = directory / path.name
        if not dest.exists() and any(node.get("name") in names for node in entries):
            raise ValueError(f"Report resources already defined elsewhere: {directory}")
        resources.append((path, dest))

    existing = [node for node in app.findall("activity")
                if node.get(ANDROID + "name") == ACTIVITY]
    if len(existing) > 1:
        raise ValueError("Duplicate report activity")
    if existing and (existing[0].get(ANDROID + "exported") != "false"
                     or existing[0].get(ANDROID + "theme") != "@style/" + THEME):
        raise ValueError("Report activity has unexpected attributes")

    manifest_text = manifest.read_text()
    if not existing:
        if manifest_text.count("</application>") != 1:
            raise ValueError("Expected one application closing tag")
        activity = (f'        <activity android:name="{ACTIVITY}" android:exported="false" '
                    f'android:label="@string/unica_bugreport_title" android:theme="@style/{THEME}" />\n')
        manifest_text = manifest_text.replace("</application>", activity + "    </application>")

    page_text = page.read_text()
    if 'android:key="unica_bugreport"' not in page_text:
        if page_text.count("</PreferenceScreen>") != 1:
            raise ValueError("Expected one UN1CA PreferenceScreen")
        row = ('    <com.samsung.android.settings.widget.SecInsetCategoryPreference />\n'
               '    <Preference android:title="@string/unica_bugreport_title" android:key="unica_bugreport">\n'
               f'        <intent android:targetPackage="com.android.settings" android:targetClass="{ACTIVITY}" />\n'
               '    </Preference>\n')
        page_text = page_text.replace("</PreferenceScreen>", row + "</PreferenceScreen>")
    ET.fromstring(manifest_text)
    ET.fromstring(page_text)

    # Reuse our own dex on repeated application; otherwise add a separate dex so
    # the donor's existing dex files do not acquire the collector's references.
    dexes = [path for path in apk.glob("smali*") if path.is_dir()
             and re.fullmatch(r"smali(?:_classes\d+)?", path.name)]
    owned = [path for path in dexes if (path / PACKAGE).is_dir()]
    if len(owned) > 1:
        raise ValueError("Report classes are present in multiple dex directories")
    index = max([1] + [int(path.name.removeprefix("smali_classes"))
                       for path in dexes if path.name != "smali"]) + 1
    dest = (owned[0] if owned else apk / f"smali_classes{index}") / PACKAGE
    shutil.copytree(source / "smali" / PACKAGE, dest, dirs_exist_ok=True)
    for path, dest in resources:
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(path, dest)
    manifest.write_text(manifest_text)
    page.write_text(page_text)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("Usage: patch_settings.py <decoded-SecSettings.apk>")
    try:
        install(Path(sys.argv[1]))
    except (OSError, ValueError, ET.ParseError) as error:
        sys.exit(f"S20 problem report integration failed: {error}")
