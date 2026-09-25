# I-08 (Wireless DeX / Smart View black screen) - client-side metadata marshalling, part B.
#
# WHAT THIS FIXES. The donor's 64-bit client (lib64/libstagefright.so) hands the stock 32-bit
# vendor OMX encoder service a 24-byte VideoNativeMetadata input buffer; the service only ever
# allocates 12. MediaCodec rejects every frame:
#   "buffer offset and size goes beyond the capacity: offset=0, size=24, cap=12"
# and WFDVideoConverter spins "clear inputbuffer" at 30Hz forever. Measured on the owner's T970,
# 2026-09-19 (`ops/WFD_I08_METADATA_ABI_20260919.md` SS3).
#
# TWO PATCHES, ONE FILE. Part A (allocateBuffersOnPort, 12->24) was already landed separately.
# This mod is part B: the marshalling call in ACodec::BaseState::onInputBufferFilled. AOSP's
# supported bridge here is kMetadataBufferTypeNativeHandleSource, and this vendor encoder refuses
# it (UnsupportedSetting, 0x80001019) - the guard AOSP puts in the way
# ("Can't marshall %s data in %zu sized buffers in %zu-bit mode") is correct, not a bug, so the
# 32-bit service can never be handed a 64-bit-shaped buffer directly. The fix is not to touch the
# vendor or the service at all: recut the guarded branch into the three AOSP calls this client
# already imports (GraphicBuffer::from -> OMXBuffer -> IOMXNode::emptyBuffer) so a real graphics
# buffer handle crosses HIDL instead of a raw metadata struct, and the 32-bit service writes its
# own 12-byte layout into it locally. Full derivation: `ops/WFD_I08_METADATA_ABI_20260919.md` S16.
#
# HARDWARE VERIFIED, gts7xlwifi (SM-T970) only, 2026-09-25. Bind-mounted over a live system_server
# (zygote restarted so the mapping actually changed - system_server is a zygote child) and over
# the smartmirroring app process, then a real Smart View session to a Miracast sink for 2+ minutes:
#   goes beyond the capacity: 0   Can't marshall: 0   clear inputbuffer: 0
#   Converter: Recvd sync frame / WFDNetworkSession: First video frame send complete
#   BufferPoolAccessor2.0 transfer counter climbing continuously (~480/5s) for the full session
# Readback of the mounted file matched the patched artifact byte-for-byte
# (sha256 4e5694f524e9d1129e778501d701c053d16221892f9eb26936fc047cd88393dc). Not yet run through a
# clean build on hardware - watch the first gts7xlwifi boot after this lands the same way.
#
# WHY NO CODENAME GATE. All four targets' work_dir lib64/libstagefright.so carried the identical
# pre-patch sha256 (5e4061020b7b7d3122fdf525809059a61b7bbfd7d523e651100c6654cc1b7833) as of
# 2026-09-25 - same donor client library across the family. The anchors below are gated on their
# own byte content, not on TARGET_CODENAME, so a codename whose file does not match is skipped,
# never guessed at. Only gts7xlwifi has been proven on a physical sink; the others ride the same
# patch on the strength of that hash match plus the client-only, vendor-untouched design (no
# per-SoC vendor code is involved at all).

_SF64="$WORK_DIR/system/system/lib64/libstagefright.so"

if [ ! -f "$_SF64" ]; then
    LOG "\033[0;33m! Nothing to do (no lib64/libstagefright.so)\033[0m"
    unset _SF64
    return 0
fi

_PRE_SHA="$(sha256sum "$_SF64" | cut -d' ' -f1)"
_DONE_SHA="4e5694f524e9d1129e778501d701c053d16221892f9eb26936fc047cd88393dc"

if [ "$_PRE_SHA" = "$_DONE_SHA" ]; then
    LOG "- lib64/libstagefright.so already carries the I-08 marshalling patch"
    unset _SF64 _PRE_SHA _DONE_SHA
    return 0
fi

# ── part A: allocateBuffersOnPort input metadata buffer size, 12 -> 24 ──────────────────────────
_A_OLD="97018052"
_A_NEW="17038052"

# ── part B: onInputBufferFilled's guarded "Can't marshall" branch -> AOSP GraphicBuffer::from /
# OMXBuffer / IOMXNode::emptyBuffer. Two anchors either side of one still-unchanged byte.
_B1_OLD="800240f9ec858e9269fdff9029453c91cafcff904ac126"
_B1_NEW="1f95017161030054800240f987220694000440f9e82300"
_B2_OLD="010040f91f9501714901899a1f9901712b001ccb6b010c8b6a1dcb938bfcffb06ba514917501899a5f0900f1a2230054c01c0694e40300aa01fdffb021643b9122fdffb042f81991a0008052e30315aa05088052871c0694"
_B2_NEW="78220694e0630091e12300917b220694e00740f9600000b4e1230091e91c0694690e40f9369940f9c80240f9085140f9e00316aaa1435fb8e2630091e31340b9a4835cf8851e40b900013fd6d2ffff171f2003d51f2003d5"

_HEX="$(xxd -p -c 0 "$_SF64")"

for _p in A B1 B2; do
    eval "_old=\$_${_p}_OLD"
    _count="$(grep -o "$_old" <<< "$_HEX" | wc -l)"
    if [ "$_count" = "0" ]; then
        LOG "\033[0;33m! Nothing to do (patch $_p anchor not found - different donor build)\033[0m"
        unset _SF64 _PRE_SHA _DONE_SHA _A_OLD _A_NEW _B1_OLD _B1_NEW _B2_OLD _B2_NEW _HEX _p _old _count
        return 0
    fi
    [ "$_count" = "1" ] || ABORT "patch $_p anchor matches $_count times in lib64/libstagefright.so - refusing to patch on an ambiguous match"
done
unset _HEX _p _old _count

LOG_STEP_IN "- Patching lib64/libstagefright.so (I-08: 64-bit client metadata marshalling)"
HEX_PATCH "$_SF64" "$_A_OLD" "$_A_NEW"   || ABORT "could not patch allocateBuffersOnPort (part A) in lib64/libstagefright.so"
HEX_PATCH "$_SF64" "$_B1_OLD" "$_B1_NEW" || ABORT "could not patch onInputBufferFilled (part B1) in lib64/libstagefright.so"
HEX_PATCH "$_SF64" "$_B2_OLD" "$_B2_NEW" || ABORT "could not patch onInputBufferFilled (part B2) in lib64/libstagefright.so"

_POST_SHA="$(sha256sum "$_SF64" | cut -d' ' -f1)"
[ "$_POST_SHA" = "$_DONE_SHA" ] \
    || ABORT "! lib64/libstagefright.so after patching is not the T970-verified binary (got $_POST_SHA)"
LOG "- lib64/libstagefright.so matches the T970-verified binary (I-08 marshalling patch)"
LOG_STEP_OUT

unset _SF64 _PRE_SHA _POST_SHA _DONE_SHA _A_OLD _A_NEW _B1_OLD _B1_NEW _B2_OLD _B2_NEW
