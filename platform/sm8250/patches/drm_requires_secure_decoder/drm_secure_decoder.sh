#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Shell port of MinsOS I-172 by MinsOS; supports the S928N EZK1 / S948N BZK1 ELF.
# https://gitlab.com/minsos1/MinsOS/-/commit/0a52421842a98b47c908b4b9adb2ef6fcaaf2d4c
# With no HIDL 1.4 plugin, both requiresSecureDecoder overloads leave *required
# false. The fallback requires video/*, level MAX/HW_SECURE_DECODE/HW_SECURE_ALL
# and securityLevel=L1. Audio, L3, HIDL 1.4 and AIDL retain their original paths.
# getPropertyStringInternal is called with the existing gLock held.
PATCH_DRM_SECURE_DECODER()
(
set -euo pipefail

VERIFY=0
if [[ "${1:-}" == --verify ]]; then VERIFY=1; shift; fi
[[ $# == 1 ]] || { echo "usage: $0 [--verify] <libmediadrm.so>" >&2; exit 1; }
FILE="$1"
FAIL() { echo "libmediadrm: $*" >&2; exit 1; }
READ_HEX() { xxd -p -c 0 -s "$1" -l "$2" "$FILE"; }
EXPECT() { [[ "$(READ_HEX "$1" "$((${#2}/2))")" == "$2" ]] || FAIL "unexpected instructions at $1"; }

# Exact ELF64 AArch64 and executable PT_LOAD layout. Never guess new offsets.
[[ "$(stat -c %s "$FILE")" == 633824 ]] || FAIL 'unsupported donor size'
EXPECT 0 7f454c46020101
EXPECT 18 b700
EXPECT 32 4000000000000000
EXPECT 54 38000c00
EXPECT 176 0100000005000000008003000000000000800300000000000080030000000000
EXPECT 224 0040000000000000
# Next LOAD starts at 0x90000, beyond the injection at 0x8c1a0..0x8c340.
EXPECT 232 010000000600000000000900000000000000090000000000
while read -r OFFSET HEX; do
    EXPECT "$OFFSET" "$HEX"
done <<'ANCHORS'
0x45074 f30308aa1c110194
0x45080 750500b400e4006f
0x4512c 7f7e00a97f0a00f9
0x45288 f30308aa97100194
0x45294 150600b400e4006fe80a0051
0x45354 7f7e00a97f0a00f9
0x3d7d8 3f2303d5ff0303d1fd7b09a9
0x89398 500000d0110645f9
0x89a10 500000d0111a46f9
0x89a40 500000d0112246f9
0x89a58 500000d0112646f9
ANCHORS

# AArch64 payload assembled at 0x8c1a0. Entrypoints: 2-arg 0x8c1a0,
# 3-arg 0x8c1c8, helper 0x8c1f0. It preserves x19/x20/fp/lr and PAC,
# owns two String8 temporaries and destroys the DrmStatus error string.
# Calls: getPropertyStringInternal=0x3d7d8; String8 ctor/default/dtor PLTs
# =0x89a40/0x89a10/0x89a58; sized delete PLT=0x89398. Returns to the
# original success/unlock at 0x4512c/0x45354 or HIDL 1.4 at 0x45084/0x45298.
PAYLOAD="$(tr -d '\n' <<'HEX'
a84e40f9680000b4f50308aab6e3fe17e00315aae10316aa22008052e30314aa
0c000094dae3fe17a84e40f9680000b4f50308aa31e4fe17e00315aae10316aa
e203172ae30314aa020000945ae4fe173f2303d5ff8301d1fd7b04a9f35305a9
fd030191c30800b47f000039810800b42800403908011b321fd9017101080054
2804403908011b321fa50171810700542808403908011b321f91017101070054
280c403908011b321f950171810600542810403908011b321fbd017101060054
281440391fbd0071a10500545f04007180000054481400511f05007108050054
f30300aaf40303aae003009121050010ecf5ff97e0230091def5ff97ff7f01a9
ff7f02a9ff1b00f9e00313aae1030091e2230091e843009148c5fe97e81340b9
a8010035e90740f9690100b42a0140395f310171010100542a0540395fc50071
a10000542a0940396a0000352a0080528a020039e8834039a8000036e81340f9
e01b40f901f97f9224f4ff97e0230091d2f5ff97e0030091d0f5ff97f35345a9
fd7b44a9ff830191bf2303d5c0035fd673656375726974794c6576656c000000
HEX
)"
[[ ${#PAYLOAD} == 832 ]] || FAIL 'invalid fallback payload'

IS_PATCHED()
{
    [[ "$(READ_HEX 208 16)" == 40430500000000004043050000000000 &&
       "$(READ_HEX 0x4507c 4)" == 491c0114 &&
       "$(READ_HEX 0x45290 4)" == ce1b0114 &&
       "$(READ_HEX 0x8c1a0 416)" == "$PAYLOAD" ]]
}
if IS_PATCHED; then echo '- libmediadrm: HIDL 1.3 secure decoder fallback verified'; exit 0; fi
[[ "$VERIFY" == 0 ]] || FAIL 'fallback not applied'
EXPECT 208 a041050000000000a041050000000000
EXPECT 0x4507c b54e40f9
EXPECT 0x45290 b54e40f9
PADDING="$(READ_HEX 0x8c1a0 416)"
[[ ${#PADDING} == 832 && -z "${PADDING//0/}" ]] || FAIL 'code cave is occupied'

TEMP="$(mktemp "$FILE.XXXXXX")"
trap 'rm -f "$TEMP"' EXIT
cp -p "$FILE" "$TEMP"
HEADER="$(READ_HEX 176 72)"
HEX_PATCH "$TEMP" "$HEADER" "${HEADER/a041050000000000a041050000000000/40430500000000004043050000000000}" || exit 1
HEX_PATCH "$TEMP" b54e40f9750500b400e4006f 491c0114750500b400e4006f || exit 1
HEX_PATCH "$TEMP" b54e40f9150600b400e4006f ce1b0114150600b400e4006f || exit 1
PREFIX=1f2003d51f2003d55000009011ae44f91062259120021fd61f2003d51f2003d5
EXPECT 0x8c180 "$PREFIX"
HEX_PATCH "$TEMP" "$PREFIX$PADDING" "$PREFIX$PAYLOAD" || exit 1
# Check the complete temporary file before replacing the input.
FILE="$TEMP" IS_PATCHED || FAIL "fallback readback failed"
mv -f "$TEMP" "$FILE"
)
