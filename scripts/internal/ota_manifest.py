#!/usr/bin/env python3
"""Generate the ChoiDujour manifest from signed full/incremental OTA zips."""
import argparse
import hashlib
import json
from pathlib import Path
import tempfile
from urllib.parse import quote, urlsplit
from zipfile import BadZipFile, ZipFile


def generate(directory, base_url):
    url = urlsplit(base_url)
    if url.scheme != "https" or not url.netloc or url.query or url.fragment:
        raise ValueError("download base URL must be HTTPS without a query or fragment")
    files = sorted(directory.glob("*.zip"))
    if not files:
        raise ValueError(f"no OTA zip files found in {directory}")
    response = []
    for path in files:
        with ZipFile(path) as archive:
            info = dict(line.split("=", 1) for line in
                        archive.read("build_info.txt").decode().splitlines() if "=" in line)
            # Require OTA signing metadata, excluding target-files/debug archives.
            archive.getinfo("META-INF/com/android/otacert")
        timestamp, incremental = int(info["timestamp"]), int(info["incremental"])
        if timestamp <= 0 or incremental < 0 or incremental >= timestamp:
            raise ValueError(f"{path.name}: invalid build/source timestamp")
        if not info["device"] or not info["version"] or not info["security_patch_version"]:
            raise ValueError(f"{path.name}: incomplete build metadata")
        with path.open("rb") as stream:
            digest = hashlib.file_digest(stream, "sha256").hexdigest()
        response.append(dict(datetime=timestamp, device=info["device"], filename=path.name,
                             id=digest, patch=info["security_patch_version"], size=path.stat().st_size,
                             urls=[base_url.rstrip("/") + "/" + quote(path.name, safe="")],
                             version=info["version"], incremental=incremental))
    return {"response": response}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    parser.add_argument("base_url", help="direct HTTPS download directory, e.g. a release's download/tag URL")
    parser.add_argument("output", type=Path, nargs="?",
                        default=Path(__file__).resolve().parents[2] / "ota/manifest.json")
    args = parser.parse_args()
    try:
        manifest = generate(args.directory, args.base_url)
    except (ValueError, KeyError, OSError, BadZipFile) as error:
        parser.exit(1, f"OTA manifest: {error}\n")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(mode="w", dir=args.output.parent, delete=False) as stream:
        json.dump(manifest, stream, indent=2, ensure_ascii=False)
        stream.write("\n")
    Path(stream.name).replace(args.output)
    print(f"Manifest saved in {args.output}")


if __name__ == "__main__":
    main()
