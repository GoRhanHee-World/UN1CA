# Experimental overseas S20 support

This port keeps the default Korean-only builds and their existing kernel pins.
Overseas mode is explicit because the old released kernel ZIPs lack Japanese NFC
support and the full overseas DTBO set. No overseas hardware has been tested.

Supported installer model lists in overseas mode:

| Target | Models |
| --- | --- |
| x1q | SM-G981N, SM-G9810, SCG01, SC-51A |
| y2q | SM-G986N, SM-G9860, SCG02, SC-52A |
| z3q | SM-G988N, SM-G9880, SCG03 |

## Configuration for a future build

Before sourcing `buildenv.sh`, export `SM8250_OVERSEAS=1` and set
`SM8250_OVERSEAS_KERNEL_ZIP` to the absolute path of a new kernel ZIP for the
selected target. Use the companion changes in
`GoRhanHee-World/android_samsung_kernel_sm8250` on `staging` when preparing that
kernel (companion source commit `bb37d5afa3e0`). The ZIP must contain
`s20-overseas.json` and the matching Image, DTB and
DTBO hashes; the ROM checks all three. The new kernel packaging keeps Korean
board IDs first, adds Japanese and Chinese IDs without duplicates, and verifies
the Samsung/NXP NFC selection code on x1q/y2q. The z3q NFC remains NXP.

The model list persists this choice in the generated config, so overseas modules
cannot accidentally run just because an unrelated environment variable is set.
The target configuration also declares the extra firmware inputs for normal
UN1CA download/extraction. The exact files below are hash-pinned by the upstream
modules; newer revisions are rejected if their files differ. Previously supplied
exact firmware extracts can be placed in the corresponding `out/fw` directories.

| Firmware extract | Upstream version | Used by |
| --- | --- | --- |
| SM-G9860_TGY | G9860ZHUCHZE1 | Dual-SIM configuration, regional PLMN, Soter HAL/libraries |
| SCG02_KDI | SCG02KDS1DXB1 | Japanese PLMN and S20+ NFC |
| SCG01_KDI | SCG01KDS1DXB1 | S20 NFC and antenna-specific RF data; x1q only |
| SM-S9480_TGY | S9480ZHS4BZIG | SecSoterService and SoterSskdsSerivce |

The firmware inputs are not included as blobs in this cherry-pick. Neither ROM
nor kernel has been built as part of this port. A future overseas build requires
these exact inputs and a newly prepared matching kernel, and fails if they are
absent. Ordinary Korean-only builds do not acquire these dependencies.

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
