# Experimental overseas S20 support

The released S20 kernels carry overseas DTBO/NFC metadata. Overseas installer
models are enabled by default; export `SM8250_OVERSEAS=0` before sourcing
`buildenv.sh` for Korean-only model assertions. No overseas hardware has been
tested. The three `zz_overseas_*` modules remain disabled until their verified
prebuilt snapshots have been imported.

Supported installer model lists in overseas mode:

| Target | Models |
| --- | --- |
| x1q | SM-G981N, SM-G9810, SCG01, SC-51A |
| y2q | SM-G986N, SM-G9860, SCG02, SC-52A |
| z3q | SM-G988N, SM-G9880, SCG03 |

## Bot-managed prebuilt snapshots

`Update prebuilt blobs` (`.github/workflows/blobs.yml`) extracts only the files
listed in each snapshot's `files.list`, checks `expected-sha256`, and opens a PR
as `github-actions[bot]`. It also uploads the snapshot as an Actions artifact.
The normal S20 build restores these paths through `.github/prebuilt-paths`;
it does not download the four full overseas firmwares.

| Device selector | Source | Measured revision | Model TAC |
| --- | --- | --- | --- |
| `g9860tgy` | SM-G9860/TGY | G9860ZHUCHZE1 | `35262211` |
| `scg01kdi` | SCG01/KDI | SCG01KDS1DXB1 | `35333011` |
| `scg02kdi` | SCG02/KDI | SCG02KDS1DXB1 | `35469611` |
| `s9480tgy` | SM-S9480/TGY | S9480ZHS4BZIG | `35499240` |

The manifest uses download IMEIs generated from the model TACs above, each
verified with a successful Samsung FUS BinaryInform response (status 200) on
2026-11-24. These are generated download identities, not copied device IMEIs.
No extra repository identity secrets are required. Dispatch the workflow
with a device selector, or `overseas` for these four sources.
The downloader requests the latest FUS revision; pinned file hashes reject an
incompatible snapshot before it is published.

TAC provenance: [G9860 model record](https://swappa.com/imei/info/352622117031190),
[SCG01 seller listing](https://www.musbi.net/sys/d/26659904.html),
[SCG02 seller listing](https://item.rakuten.co.jp/amemoba/27630740/), and
[SM-S9480 TAC record](https://fccid.io/TAC/35499240). The TAC sources identify the
models; the generated download identities are verified separately against FUS.

After merging the verified bot PRs, remove `disable` from the three
`platform/sm8250/patches/zz_overseas_*` modules to include their patches. Keep the
existing per-file and vendor compatibility checks. `g9860tgy`, `scg02kdi`, and
`s9480tgy` are shared by all targets; `scg01kdi` supplies x1q's antenna RF data.
The two NFC snapshots also contain the interface library used for comparison;
`g9860tgy` includes the QSEE library for the same compatibility check.

The configured release kernels are checked by `verify_kernel.sh`. To override a
kernel, set `SM8250_OVERSEAS_KERNEL_ZIP` to an absolute path. Its
`s20-overseas.json` must identify the selected target and match the Image, DTB,
and DTBO hashes. Korean board IDs remain first; x1q/y2q require Samsung/NXP NFC
selection, while z3q keeps NXP.

## Runtime behavior

- SM-G9810/G9860/G9880 run the TGY SIM configuration service; Korean and Japanese
  models keep the original service. The shared vendor already declares slot2,
  so its declarations are checked rather than duplicated. Overseas mode keeps
  the donor's dual-tray framework path instead of forcing `isOneTray()` true.
- Soter starts only on the three G98x0 models, whose original NON-HLOS supplies
  the required trustlet. This port never writes NON-HLOS or adds IFAA/Alipay.
- KDI/DCM sales codes select the Samsung NFC HAL on x1q/y2q. Other sales codes
  retain NXP; z3q keeps its original NXP stack. FeliCa middleware is not added.
- Kernel modem firmware and physical partition differences remain subject to
  overseas device testing. Installer inclusion is experimental compatibility,
  not a claim of verified calls, mobile data, payment or NFC.

The modules run after the shared vendor replacement (`zz_overseas_*`) so that
their init, VINTF and property changes survive that replacement. All integration
helpers use shell, awk, sed, jq and standard command-line tools; no Python helper
is used.

## Upstream provenance

Cherry-picked from the MinsOS `y2q` branch:

- `ae929668dc95b5d96789cd7b091ef3bd72b55cd9`: dual SIM.
- `1675ba314fc1a559efa1b1d6c80b81896727f47e`: Japanese NFC module.
- `e62532a60e786c32cded20530b368b8bd01fb86c`: Japanese S20 NFC extension.
- `faedd7ddffc8b1891d64ead64e561d17eb06d38a`: WeChat Soter.
- Kernel patch 0041 from `bbbc081c9d01587be11072dc5c47feb036024a62` is
  retained under `kernel/` and applied to the companion kernel source. Regional
  DTBO selection is adapted from MinsOS `tools/build_kernel_local.sh` on `y2q`.

Upstream: https://gitlab.com/minsos1/MinsOS (GPL-3.0; kernel changes GPL-2.0).
