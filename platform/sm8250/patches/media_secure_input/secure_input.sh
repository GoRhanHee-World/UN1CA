# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later
# MinsOS I-09, re-derived for the S928N EZK1 ARM64 libstagefright.
# https://gitlab.com/minsos1/MinsOS/-/commit/55462c8c79e7671b3a671c3d457dfd05e9292b95
# Widevine may return the entire secure allocation instead of the access-unit
# length. Save the subsample sum, then clamp OMXBuffer::mRangeLength before
# IOMXNode::emptyBuffer. Only native-handle SecureBuffer objects use the spare
# mPointer slot; clear buffers, raw pointers and CAS retain their original paths.
PATCH_MEDIA_SECURE_INPUT()
(
set -euo pipefail

VERIFY=0
if [[ "${1:-}" == --verify ]]; then VERIFY=1; shift; fi
[[ $# == 1 ]] || { ABORT 'Usage: PATCH_MEDIA_SECURE_INPUT [--verify] <libstagefright.so>'; exit 1; }
FILE="$1"
FAIL() { ABORT "Secure OMX input: $*"; exit 1; }
READ_HEX() { xxd -p -c 0 -s "$1" -l "$2" "$FILE"; }
EXPECT() { [[ "$(READ_HEX "$1" "$((${#2}/2))")" == "$2" ]] || FAIL "unexpected bytes at $1"; }

# Pin the donor, executable mapping, field offsets and instructions around both
# hooks. These anchors are outside the independent I-08 and encoder patches.
[[ "$(stat -c %s "$FILE")" == 2709952 ]] || FAIL 'unsupported donor size'
EXPECT 0 7f454c46020101
EXPECT 18 b700
EXPECT 32 4000000000000000
EXPECT 54 38000d00
EXPECT 176 010000000500000000800b000000000000800b000000000000800b0000000000e0c61b0000000000e0c61b00000000000040000000000000
while read -r OFFSET HEX; do
    EXPECT "$OFFSET" "$HEX"
done <<'ANCHORS'
0x348 040000001000000003000000474e5500add70362863989d342ce0486c4ad5b0c
0xfcd10 3f2303d5fd7bbaa9fc6f01a9fa6702a9f85f03a9f65704a9f44f05a9fd030091ff8306d1080040f9e90b00f029a11891
0xfcecc fc1300f9b63340f9
0xfced8 a8031df8df0600f1a1000054080340b968000035080740b9
0xfcef4 a84240f9fc030391a80200b4
0xcc6d0 a8435fb8369940f9e0630091e10314aae80b00b9ad7c069480698ad2d80240f9a8835cf8202dbbf2971e40b900c5d6f2e10318aae80300f92048fbf2db740694
0xcc714 e10b40b9e2630091e31340b9e40340f9e00316aae503172a00013fd6
0x10b2a4 c80b0090084121919f1600f9880200f9610240f9811a00f9
0xbaebc 00f59ed2809ba5f2e035caf2a0e5f7f2ebba0694e7ffff17
0xbb000 5f2403d588278ed2c8fabbf288b9c5f2
ANCHORS

# AArch64 code in existing executable padding before __cfi_check:
# queue=0xbaee0 (resume 0xfced8), submit=0xbaf80 (resume 0xcc714).
# SecureBuffer vtable=0x283850, mPointer=+0x28, mHandle=+0x30.
# queue: require secure=true and mCrypto!=NULL; sum two uint32_t fields using
# 64-bit arithmetic, reject overflow, and store only a uint32_t-sized result.
# submit: consume the saved size once, never enlarge the existing OMX range.
# x0..x7, x15..x30 and sp are preserved; displaced x8 loads are replayed.
PAYLOAD="$(tr -d '\n' <<'HEX'
970300368a1a40f94a0300b44b0140f94c0e00b08c4121917f010ceba1020054
4b1940f96b0200b45f1500f9ab4240f90b0200b4f60100b4d80100b4e9031faa
eb031faa0c0f0b8b8d394029ad010e8b29010dabe20000546b0500917f0116eb
23ffff542dfd60d34d0000b5491500f908008092e10701140000000000000000
0000000000000000000000000000000000000000000000000000000000000000
8a0240f9ea0100b44b0140f94c0e00b08c4121917f010ceb410100544b1940f9
0b0100b4491540f95f1500f9a90000b4eb2340b93f010beb48000054e92300b9
085340f9d4450014
HEX
)"
[[ ${#PAYLOAD} == 464 ]] || FAIL 'invalid clamp payload'

IS_PATCHED()
{
    [[ "$(READ_HEX 0xfced4 4)" == 03f8fe17 &&
       "$(READ_HEX 0xcc710 4)" == 1cbaff17 &&
       "$(READ_HEX 0xbaee0 232)" == "$PAYLOAD" ]]
}
if IS_PATCHED; then
    LOG '- libstagefright: S928N EZK1 secure OMX input clamp verified'
    exit 0
fi
[[ "$VERIFY" == 0 ]] || FAIL 'clamp not fully applied'
EXPECT 0xfced4 08008092
EXPECT 0xcc710 085340f9
PADDING="$(READ_HEX 0xbaee0 232)"
[[ ${#PADDING} == 464 && -z "${PADDING//0/}" ]] || FAIL 'code cave is occupied'
PREFIX=00f59ed2809ba5f2e035caf2a0e5f7f2ebba0694e7ffff17000000000000000000000000
EXPECT 0xbaebc "$PREFIX"

TEMP="$(mktemp "$FILE.XXXXXX")"
trap 'rm -f "$TEMP" "$TEMP.tmp"' EXIT
cp -p "$FILE" "$TEMP"

# Use UN1CA HEX_PATCH only on uniquely anchored patterns. Verify the complete
# temporary output before replacing the input, so partial failures are atomic.
PATCH_UNIQUE()
{
    local COUNT
    COUNT="$( { xxd -p -c 0 "$TEMP" | grep -o "$1" || true; } | wc -l)"
    [[ "$COUNT" == 1 ]] || FAIL 'patch anchor is missing or ambiguous'
    HEX_PATCH "$TEMP" "$1" "$2" || exit 1
}
PATCH_UNIQUE fc1300f9b63340f908008092a8031df8 fc1300f9b63340f903f8fe17a8031df8
PATCH_UNIQUE 2048fbf2db740694085340f9e10b40b9 2048fbf2db7406941cbaff17e10b40b9
PATCH_UNIQUE "$PREFIX$PADDING" "$PREFIX$PAYLOAD"
FILE="$TEMP" IS_PATCHED || FAIL 'clamp readback failed'
chmod --reference="$FILE" "$TEMP"
mv -f "$TEMP" "$FILE"
LOG '- libstagefright: S928N EZK1 secure OMX input clamp applied'
)
