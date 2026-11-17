# S20 problem reports

The common Settings mod calls this platform hook after installing the UN1CA
Settings page. Only x1q, y2q and z3q on Android 17 or newer receive the collector.
The report activity is not exported; it runs inside Settings and performs
collection on a worker thread.

Settings > UN1CA Settings > Create problem report collects logcat buffers,
`dumpsys input`, the last day's DropBox entries and readable recovery logs into
`/sdcard/UN1CA/reports/UN1CA_report_<timestamp>.zip`. Unavailable data is listed in
the archive's README. The imported scrubber masks known device/account/network
identifiers and recognized identifier patterns. Users can inspect the archive
before sharing it. Collection does not upload anything; Share opens the Android
chooser with a MediaStore content URI and a read grant.

This is a partial cherry-pick of MinsOS
`73daaddd59729739c33f35e2cd637824196b0ac8`, with the complete report and scrubber
class families taken from `65905e2cb2cf54f65e0552fced188fff90046406` to include
subsequent collector fixes. Sources:

- `unica-mods/mods/minsos_ota/smali/com/minsos/settings/MinsOsBugReport*.smali`
- `unica-mods/mods/minsos_ota/smali/com/minsos/settings/MinsOsScrub*.smali`
- Resource, property and storage helper methods from
  `MinsOsUpdatePreferenceController.smali` and `MinsOsDownloader.smali`.

The port changes the namespace, strings, storage and recovery-log paths, and
removes updater dependencies. `ReportUtils` contains only resource lookup,
property reading, string formatting and the report storage directory. No OTA,
beta enrollment or automatic diagnostic upload code is included.

Upstream: https://gitlab.com/minsos1/MinsOS (GPL-3.0).
