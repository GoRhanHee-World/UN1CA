# shellcheck shell=bash
# The bundled SketchBook has a reduced Java SDK: its ObjectBase table matches
# the first 78 entries in libSPenModel, but the library registers 95 entries.
# The extra 17 methods belong to the full Notes SDK and abort registration.
SKETCHBOOK_DIR="$APKTOOL_DIR/system/app/SketchBook/SketchBook.apk"
SKETCHBOOK_LIB="$SKETCHBOOK_DIR/lib/arm64-v8a/libSPenModel.so"
SKETCHBOOK_CLASS="$(find "$SKETCHBOOK_DIR" -path '*/com/samsung/android/sdk/pen/document/SpenObjectBase.smali' -type f)"
if [ ! -f "$SKETCHBOOK_CLASS" ] || [ ! -f "$SKETCHBOOK_LIB" ]; then
    ABORT "SketchBook Java/native SDK files are missing"
    return 1
fi
SKETCHBOOK_ABI="$(awk '/^\.method .* native ObjectBase_/ {print $NF}' "$SKETCHBOOK_CLASS" | LC_ALL=C sort | sha256sum | cut -d ' ' -f 1)"
if [ "$SKETCHBOOK_ABI" != "cdfdd3357db35929d4d604e786397254fe4657e814ba32494d86be8eca99a77c" ]; then
    ABORT "SketchBook Java SDK changed; recheck ObjectBase JNI registration"
    return 1
fi
case "$(sha256sum "$SKETCHBOOK_LIB" | cut -d ' ' -f 1)" in
    50ed266e2879b67ab58660ce11c579a24a9d37be2765df7da902935d2e16716b)
        # ObjectBase_OnLoad: mov w3, #95 -> mov w3, #78. Preserve every
        # function implementation and register all methods in the shared prefix.
        HEX_PATCH "$SKETCHBOOK_LIB" \
            "e00313aae30b8052085d43f900013fd6" \
            "e00313aac3098052085d43f900013fd6" || return 1
        ;;
    d7021c224546f6f643949370ecc30cb1809b824d9a95d4c87c7d03bcf03b6495) ;;
    *)
        ABORT "SketchBook native SDK changed; recheck ObjectBase JNI registration"
        return 1
        ;;
esac
if [ "$(sha256sum "$SKETCHBOOK_LIB" | cut -d ' ' -f 1)" != "d7021c224546f6f643949370ecc30cb1809b824d9a95d4c87c7d03bcf03b6495" ]; then
    ABORT "SketchBook ObjectBase registration patch failed"
    return 1
fi
unset SKETCHBOOK_DIR SKETCHBOOK_LIB SKETCHBOOK_CLASS SKETCHBOOK_ABI
