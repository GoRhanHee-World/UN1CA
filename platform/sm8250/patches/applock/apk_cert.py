#!/usr/bin/env python3
"""Measure an APK: file hash, v2 signing-block certificate, manifest identity.

The KernelSU driver compiles in exactly one accepted manager certificate as
(length, sha256) -- KSU_NEXT_SIZE / KSU_NEXT_HASH. Those two numbers must equal
the v2cert_len / v2cert_sha256 printed here for the manager to be trusted.

Pure stdlib, python3.8+, Windows and Linux.
"""
import argparse
import hashlib
import struct
import sys
import zipfile

MAGIC = b"APK Sig Block 42"
V2_ID = 0x7109871A
KNOWN_IDS = {V2_ID: "v2", 0xF05368C0: "v3", 0x1B93AD61: "v3.1", 0x2B09189E: "stamp"}


class BadApk(Exception):
    pass


# ---------------------------------------------------------------- signing block

def _central_dir_offset(data):
    # EOCD is the last 22+comment bytes; comment is <= 64K so scan that window.
    for i in range(len(data) - 22, max(-1, len(data) - 22 - 65536), -1):
        if data[i:i + 4] == b"PK\x05\x06":
            off = struct.unpack_from("<I", data, i + 16)[0]
            if off == 0xFFFFFFFF:
                raise BadApk("zip64 APK not supported")
            return off
    raise BadApk("no end-of-central-directory record (not a zip)")


def signing_blocks(data):
    """{block_id: value_bytes} from the APK Signing Block; {} if there is none."""
    cd = _central_dir_offset(data)
    if cd < 24 or data[cd - 16:cd] != MAGIC:
        return {}
    size = struct.unpack_from("<Q", data, cd - 24)[0]
    start = cd - 8 - size
    if start < 0 or struct.unpack_from("<Q", data, start)[0] != size:
        raise BadApk("APK Signing Block size fields disagree")
    out, p, end = {}, start + 8, cd - 24
    while p < end:
        (pair_len,) = struct.unpack_from("<Q", data, p)
        (block_id,) = struct.unpack_from("<I", data, p + 8)
        out[block_id] = data[p + 12:p + 8 + pair_len]
        p += 8 + pair_len
    return out


def _u32_chunks(buf):
    """Iterate an APK-scheme length-prefixed sequence (uint32 LE length, payload)."""
    p = 0
    while p + 4 <= len(buf):
        (n,) = struct.unpack_from("<I", buf, p)
        yield buf[p + 4:p + 4 + n]
        p += 4 + n


def first_cert(value):
    """First signer's first X.509 certificate (DER) from a v2 or v3 block value.

    v2 signer = signed_data | signatures | public_key
    v3 signer = signed_data | min_sdk | max_sdk | signatures | public_key
    Both signed_data start with digests then certificates, so this works for both.
    """
    signers = next(_u32_chunks(value))
    signer = next(_u32_chunks(signers))
    signed_data = next(_u32_chunks(signer))
    parts = _u32_chunks(signed_data)
    next(parts)                       # digests
    certs = next(parts)
    return next(_u32_chunks(certs))


# ------------------------------------------------------------------------ axml

RES_STRING_POOL, RES_START_TAG = 0x0001, 0x0102
TYPE_STRING, TYPE_INT_DEC, TYPE_INT_HEX, TYPE_INT_BOOL = 0x03, 0x10, 0x11, 0x12


def _varint(buf, p):
    """AXML UTF-8 length: high bit set means a 2-byte big-endian-ish length."""
    if buf[p] & 0x80:
        return ((buf[p] & 0x7F) << 8) | buf[p + 1], p + 2
    return buf[p], p + 1


def _string_pool(buf, off):
    count, _styles, flags, strings_start = struct.unpack_from("<IIII", buf, off + 8)
    utf8 = bool(flags & 0x100)
    offsets = struct.unpack_from("<%dI" % count, buf, off + 28)
    base = off + strings_start
    out = []
    for o in offsets:
        p = base + o
        if utf8:
            _chars, p = _varint(buf, p)   # length in characters, then in bytes
            n, p = _varint(buf, p)
            out.append(buf[p:p + n].decode("utf-8", "replace"))
        else:
            n, p = struct.unpack_from("<H", buf, p)[0], p + 2
            if n & 0x8000:                # >32767 chars: second u16 holds the rest
                n = ((n & 0x7FFF) << 16) | struct.unpack_from("<H", buf, p)[0]
                p += 2
            out.append(buf[p:p + n * 2].decode("utf-16-le", "replace"))
    return out


def parse_axml(buf):
    """[(tag_name, {attr_name: value}), ...] in document order."""
    pool, tags = [], []
    p = 8  # skip file header
    while p + 8 <= len(buf):
        ctype, _hsize, csize = struct.unpack_from("<HHI", buf, p)
        if csize < 8:
            break
        if ctype == RES_STRING_POOL:
            pool = _string_pool(buf, p)
        elif ctype == RES_START_TAG:
            name = pool[struct.unpack_from("<I", buf, p + 20)[0]]
            attr_start, _asize, acount = struct.unpack_from("<HHH", buf, p + 24)
            attrs = {}
            for i in range(acount):
                a = p + 16 + attr_start + i * 20
                nm, raw = struct.unpack_from("<II", buf, a + 4)
                dtype, data = struct.unpack_from("<BI", buf, a + 15)
                if dtype == TYPE_STRING:
                    val = pool[data]
                elif dtype == TYPE_INT_BOOL:
                    val = bool(data)
                elif dtype == TYPE_INT_HEX:
                    val = hex(data)
                elif dtype == TYPE_INT_DEC:
                    val = data
                elif raw != 0xFFFFFFFF:
                    val = pool[raw]
                else:
                    val = "@0x%08x" % data
                attrs[pool[nm]] = val
            tags.append((name, attrs))
        p += csize
    return tags


# ----------------------------------------------------------------------- probe

def measure(path):
    with open(path, "rb") as f:
        data = f.read()
    if not zipfile.is_zipfile(path):
        raise BadApk("not a zip file")
    blocks = signing_blocks(data)
    if V2_ID not in blocks:
        raise BadApk("no v2 signing block")
    cert = first_cert(blocks[V2_ID])
    with zipfile.ZipFile(path) as z:
        if "AndroidManifest.xml" not in z.namelist():
            raise BadApk("no AndroidManifest.xml")
        tags = parse_axml(z.read("AndroidManifest.xml"))
    man = next((a for t, a in tags if t == "manifest"), {})
    return {
        "path": path,
        "size": len(data),
        "sha256": hashlib.sha256(data).hexdigest(),
        "cert_len": len(cert),
        "cert_sha256": hashlib.sha256(cert).hexdigest(),
        "package": man.get("package", "?"),
        "versionCode": man.get("versionCode", "?"),
        "versionName": man.get("versionName", "?"),
        "blocks": blocks,
        "tags": tags,
    }


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("apk", nargs="+")
    ap.add_argument("--expect-size", type=lambda s: int(s, 0),
                    help="required v2 certificate length (decimal or 0x hex)")
    ap.add_argument("--expect-hash", help="required v2 certificate sha256")
    args = ap.parse_args(argv)
    if (args.expect_size is None) != (args.expect_hash is None):
        ap.error("--expect-size and --expect-hash must be given together")

    rc = 0
    for path in args.apk:
        try:
            m = measure(path)
        except (BadApk, OSError, struct.error, IndexError, StopIteration) as e:
            print("%s ERROR %s" % (path, e), file=sys.stderr)
            rc = 1
            continue
        print("%s %d %s %d(0x%04x) %s %s %s %s" % (
            m["path"], m["size"], m["sha256"], m["cert_len"], m["cert_len"],
            m["cert_sha256"], m["package"], m["versionCode"], m["versionName"]))
        if args.expect_size is not None:
            if m["cert_len"] != args.expect_size:
                print("%s MISMATCH cert length %d != expected %d"
                      % (path, m["cert_len"], args.expect_size), file=sys.stderr)
                rc = 1
            if m["cert_sha256"] != args.expect_hash.lower():
                print("%s MISMATCH cert sha256 %s != expected %s"
                      % (path, m["cert_sha256"], args.expect_hash.lower()), file=sys.stderr)
                rc = 1
    return rc


if __name__ == "__main__":
    sys.exit(main())
