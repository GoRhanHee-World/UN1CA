# SM8250 auxiliary ARM32 runtime

This package provides the runtime used by `platform/sm8250/patches/island32`
when the main system donor does not include ARM32 support. Builds use these
files through `ADD_TO_WORK_DIR "dm3qksx"`; no S918N firmware download is needed.

The payload is 43 ARM32 system libraries, one hybrid runtime APEX containing
both ARM32 and ARM64 Bionic, and five symbolic links into that APEX. The
payload totals 19,342,208 bytes, excluding metadata and symlinks.

## Source and verification

- Device/CSC: Samsung Galaxy S23 Ultra, `SM-S918N/KOO`.
- Firmware: `S918NKSU8GZIF/S918NOKR8GZIF/S918NKSU8GZIF`.
- Runtime APEX SHA-256: `14e2490e2ed1df62d91988e22f617952770b5bbb43fd6de206bbee81fd182769`.
- The library hashes and APEX hash were previously recorded in this repository
  at commit `a15be22908aa30f3dd185a8d20064114a451e295`. All 43 library hashes
  match the MinsOS island library list used for the original port.

These files were recovered by reading the installed x1q system image and
matched against those recorded hashes before being added here. The APEX is
stored unchanged, including its original signatures. `SHA256SUMS` covers all
44 regular payload files; verify it from this directory with:

```sh
sha256sum --check SHA256SUMS
```

The links retain their installed targets:

| Link | Target |
| --- | --- |
| `system/lib/libc.so` | `/apex/com.android.runtime/lib/bionic/libc.so` |
| `system/lib/libm.so` | `/apex/com.android.runtime/lib/bionic/libm.so` |
| `system/lib/libdl.so` | `/apex/com.android.runtime/lib/bionic/libdl.so` |
| `system/lib/libdl_android.so` | `/apex/com.android.runtime/lib/bionic/libdl_android.so` |
| `system/bin/linker` | `/apex/com.android.runtime/bin/linker` |

`fs_config-system` and `file_context-system` provide the permissions and
SELinux labels consumed by the existing build helper.
