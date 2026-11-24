# I-08: bridge the donor's 64-bit metadata buffers to the stock 32-bit OMX service.
# Select donor-specific instruction patterns and patch the matching bytes.
# Imported from MinsOS f8aa3918, WFD portion of 9b79d33c, and 6880ef44.
# UN1CA requires this patch on its ARM64 WFD path, so unknown/partial inputs
# fail instead of silently disabling the fix.
_SF64="$WORK_DIR/system/system/lib64/libstagefright.so"

if [ ! -f "$_SF64" ]; then
    ABORT "I-08: missing lib64/libstagefright.so"
    unset _SF64
    return 1
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
if [[ "$_HEX" == *"$_B1_NEW"* && "$_HEX" == *"$_B2_NEW"* && "$_HEX" != *"$_A_OLD"* ]]; then
    LOG "- lib64/libstagefright.so already carries the I-08 marshalling patch"
    unset _SF64 _A_OLD _A_NEW _B1_OLD _B1_NEW _B2_OLD _B2_NEW _HEX
    return 0
fi

# MinsOS: the y2q One UI 9 donor (S928N) and the tablet 2.0.0 One UI 9 donor (X810 FZK2) build ACodec
# differently, so part B needs its own anchors for each.
# - S928N: re-derived by gemini 2026-10-18 (`ops/y2q_s24u/r23/issue_wfd/i08/PORT_NOTES.md`). Hardware
#   verified on the owner's S20+ (r23, bind mount over remotedisplay, real Smart View session to a PC sink:
#   capacity / Can't marshall / clear inputbuffer 0, first video frame sent).
# - X810 FZK2 (tablet 2.0.0): re-derived 2026-11-17 (allocateBuffersOnPort @0xdb0c4, onInputBufferFilled
#   @0xcb770..0xcb7e0), same 28 instructions, registers and stack/struct offsets as 8.5; only the 4 PLT call
#   words differ from S928N (targets checked through .rela.plt). NOT yet hardware verified. With FZK2 input
#   I-08 and wfd_i09_clamp commute (fw+camera+fortify -> both orders 385cc583...).
# - S948N BZK1 (y2q, Nov 2026 security build): re-derived by gemini 2026-11-19 (`ops/y2q_bzk1/i08/PORT_NOTES.md`).
#   BZJB's libstagefright is byte-identical to the S928N one, so BZJB takes the S928N set; in BZK1 both functions
#   sit at the same offsets and the patched bytes equal the S928N patch except 4 PLT call words, each moved by the
#   same +0x28 as all 184 untouched call words of the two functions (`ops/y2q_bzk1/i08/claude_check.py`).
#   NOT yet hardware verified on BZK1.
# Earlier mods (camera, media_encoder_fortify) and the later wfd_i09_clamp touch other bytes of this file,
# so the pattern set is chosen and checked by instruction content.
_S928N_B1_OLD="800240f90c1a905249fdffd029c11f91aafcffd04a5d0a"
_S928N_B1_NEW="1f95017161030054800240f9f77a0694000440f9e82300"
_S928N_B2_OLD="010040f91f9501714901899a1f9901718b0301cb6b010c8b6a1dcb936bfcffd06b410c917501899a5f0900f1a2230054c4740694e40300aae1fcfff021ec049102fdffd0422c3591a0008052e30315aa050880528b740694"
_S928N_B2_NEW="e87a0694e0630091e1230091eb7a0694e00740f9600000b4e1230091ed740694690e40f9369940f9c80240f9085140f9e00316aaa1435fb8e2630091e31340b9a4835cf8851e40b900013fd6d1ffff171f2003d51f2003d5"

_FZK2_B1_OLD="800240f90c1a905249fdfff0291d2191aafcfff04a210d"
_FZK2_B1_NEW="1f95017161030054800240f91d7b0694000440f9e82300"
_FZK2_B2_OLD="010040f91f9501714901899a1f9901718b0301cb6b010c8b6a1dcb936bfcfff06bf50c917501899a5f0900f1a2230054ea740694e40300aa01fdff90213c089102fdfff0427c3891a0008052e30315aa05088052b1740694"
_FZK2_B2_NEW="0e7b0694e0630091e1230091117b0694e00740f9600000b4e123009113750694690e40f9369940f9c80240f9085140f9e00316aaa1435fb8e2630091e31340b9a4835cf8851e40b900013fd6d1ffff171f2003d51f2003d5"

_BZK1_B1_OLD="800240f90c1a905249fdffd0295d2291aafcffd04a610e"
_BZK1_B1_NEW="1f95017161030054800240f91f7b0694000440f9e82300"
_BZK1_B2_OLD="010040f91f9501714901899a1f9901718b0301cb6b010c8b6a1dcb936bfcffd06b350e917501899a5f0900f1a2230054ec740694e40300aae1fcfff0217c099102fdffd042bc3991a0008052e30315aa05088052b3740694"
_BZK1_B2_NEW="107b0694e0630091e1230091137b0694e00740f9600000b4e123009115750694690e40f9369940f9c80240f9085140f9e00316aaa1435fb8e2630091e31340b9a4835cf8851e40b900013fd6d1ffff171f2003d51f2003d5"

if [ "$( { grep -o "$_S928N_B2_NEW" <<< "$_HEX" || true; } | wc -l)" = "1" ] &&
        [ "$( { grep -o "$_S928N_B1_NEW" <<< "$_HEX" || true; } | wc -l)" = "1" ] &&
        [[ "$_HEX" != *"$_A_OLD"* ]]; then
    LOG "- lib64/libstagefright.so already carries the I-08 marshalling patch (S928N build)"
    unset _SF64 _A_OLD _A_NEW _B1_OLD _B1_NEW _B2_OLD _B2_NEW _HEX _S928N_B1_OLD _S928N_B1_NEW _S928N_B2_OLD _S928N_B2_NEW _FZK2_B1_OLD _FZK2_B1_NEW _FZK2_B2_OLD _FZK2_B2_NEW _BZK1_B1_OLD _BZK1_B1_NEW _BZK1_B2_OLD _BZK1_B2_NEW
    return 0
fi
if [ "$( { grep -o "$_FZK2_B2_NEW" <<< "$_HEX" || true; } | wc -l)" = "1" ] &&
        [ "$( { grep -o "$_FZK2_B1_NEW" <<< "$_HEX" || true; } | wc -l)" = "1" ] &&
        [[ "$_HEX" != *"$_A_OLD"* ]]; then
    LOG "- lib64/libstagefright.so already carries the I-08 marshalling patch (X810 FZK2 build)"
    unset _SF64 _A_OLD _A_NEW _B1_OLD _B1_NEW _B2_OLD _B2_NEW _HEX _S928N_B1_OLD _S928N_B1_NEW _S928N_B2_OLD _S928N_B2_NEW _FZK2_B1_OLD _FZK2_B1_NEW _FZK2_B2_OLD _FZK2_B2_NEW _BZK1_B1_OLD _BZK1_B1_NEW _BZK1_B2_OLD _BZK1_B2_NEW
    return 0
fi
if [ "$( { grep -o "$_BZK1_B2_NEW" <<< "$_HEX" || true; } | wc -l)" = "1" ] &&
        [ "$( { grep -o "$_BZK1_B1_NEW" <<< "$_HEX" || true; } | wc -l)" = "1" ] &&
        [[ "$_HEX" != *"$_A_OLD"* ]]; then
    LOG "- lib64/libstagefright.so already carries the I-08 marshalling patch (S948N BZK1 build)"
    unset _SF64 _A_OLD _A_NEW _B1_OLD _B1_NEW _B2_OLD _B2_NEW _HEX _S928N_B1_OLD _S928N_B1_NEW _S928N_B2_OLD _S928N_B2_NEW _FZK2_B1_OLD _FZK2_B1_NEW _FZK2_B2_OLD _FZK2_B2_NEW _BZK1_B1_OLD _BZK1_B1_NEW _BZK1_B2_OLD _BZK1_B2_NEW
    return 0
fi
_DONOR_TAG="T970 build"
if [ "$( { grep -o "$_B1_OLD" <<< "$_HEX" || true; } | wc -l)" = "0" ]; then
    if [ "$( { grep -o "$_S928N_B1_OLD" <<< "$_HEX" || true; } | wc -l)" = "1" ]; then
        _B1_OLD="$_S928N_B1_OLD"; _B1_NEW="$_S928N_B1_NEW"; _B2_OLD="$_S928N_B2_OLD"; _B2_NEW="$_S928N_B2_NEW"
        _DONOR_TAG="S928N build"
    elif [ "$( { grep -o "$_FZK2_B1_OLD" <<< "$_HEX" || true; } | wc -l)" = "1" ]; then
        _B1_OLD="$_FZK2_B1_OLD"; _B1_NEW="$_FZK2_B1_NEW"; _B2_OLD="$_FZK2_B2_OLD"; _B2_NEW="$_FZK2_B2_NEW"
        _DONOR_TAG="X810 FZK2 build"
    elif [ "$( { grep -o "$_BZK1_B1_OLD" <<< "$_HEX" || true; } | wc -l)" = "1" ]; then
        _B1_OLD="$_BZK1_B1_OLD"; _B1_NEW="$_BZK1_B1_NEW"; _B2_OLD="$_BZK1_B2_OLD"; _B2_NEW="$_BZK1_B2_NEW"
        _DONOR_TAG="S948N BZK1 build"
    fi
fi
unset _S928N_B1_OLD _S928N_B1_NEW _S928N_B2_OLD _S928N_B2_NEW _FZK2_B1_OLD _FZK2_B1_NEW _FZK2_B2_OLD _FZK2_B2_NEW _BZK1_B1_OLD _BZK1_B1_NEW _BZK1_B2_OLD _BZK1_B2_NEW

_old=""
for _p in A B1 B2; do
    eval "_old=\$_${_p}_OLD"
    _count="$( { grep -o "$_old" <<< "$_HEX" || true; } | wc -l)"
    if [ "$_count" = "0" ]; then
        ABORT "I-08: patch $_p anchor missing or partially patched; re-derive for this donor"
        unset _SF64 _A_OLD _A_NEW _B1_OLD _B1_NEW _B2_OLD _B2_NEW _HEX _DONOR_TAG _p _old _count
        return 1
    fi
    [ "$_count" = "1" ] || { ABORT "patch $_p anchor matches $_count times in lib64/libstagefright.so - refusing to patch on an ambiguous match"; return 1; }
done
unset _HEX _p _old _count

LOG_STEP_IN "- Patching lib64/libstagefright.so (I-08: 64-bit client metadata marshalling)"
HEX_PATCH "$_SF64" "$_A_OLD" "$_A_NEW"   || return 1
HEX_PATCH "$_SF64" "$_B1_OLD" "$_B1_NEW" || return 1
HEX_PATCH "$_SF64" "$_B2_OLD" "$_B2_NEW" || return 1

_HEX="$(xxd -p -c 0 "$_SF64")"
# Verify the changed instruction sequences directly.
_new=""
for _p in A B1 B2; do
    eval "_new=\$_${_p}_NEW; _old=\$_${_p}_OLD"
    [ "$( { grep -o "$_old" <<< "$_HEX" || true; } | wc -l)" = "0" ] \
        || { ABORT "! lib64/libstagefright.so part $_p still carries its old bytes ($_DONOR_TAG)"; return 1; }
    [ "$_p" = A ] || [ "$( { grep -o "$_new" <<< "$_HEX" || true; } | wc -l)" = "1" ] \
        || { ABORT "! lib64/libstagefright.so part $_p did not land exactly once ($_DONOR_TAG)"; return 1; }
done
unset _HEX _p _new _old
LOG "- lib64/libstagefright.so carries the I-08 marshalling patch ($_DONOR_TAG)"
LOG_STEP_OUT

unset _SF64 _DONOR_TAG _A_OLD _A_NEW _B1_OLD _B1_NEW _B2_OLD _B2_NEW
