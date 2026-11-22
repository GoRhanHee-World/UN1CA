#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail

if [ "${1:-}" = "--help" ]; then
    cat <<'EOF'
Generate this fork's persistent OTA key once; never replace an existing key.
Usage: scripts/generate_ota_key.sh

Back up security/unica_ota.{pk8,x509.pem} securely; both are ignored by Git.
CI secrets OTA_KEY_PK8 and OTA_KEY_PEM require base64 of these files.
ROM_OTA_ENABLED defaults to true; ROM_OTA_URL overrides the update manifest.
First install an OTA-enabled ROM through recovery, then publish signed packages:
  scripts/generate_ota_manifest.sh ZIP_DIRECTORY HTTPS_DOWNLOAD_BASE_URL [OUTPUT]
The default manifest output is ota/manifest.json. Upload zips first, then publish
the manifest on the seventeen branch. GoFile landing pages are not direct zip URLs.
EOF
    exit 0
fi

TASK_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$TASK_ROOT"
if [ -e security/unica_ota.pk8 ] || [ -e security/unica_ota.x509.pem ]; then
    echo "OTA key already exists; refusing to overwrite either file" >&2
    exit 1
fi
umask 077
KEY_TMP="$(mktemp -d)"
trap 'rm -rf "$KEY_TMP"' EXIT
openssl req -new -x509 -newkey rsa:4096 -nodes -sha256 -days 10000 \
    -subj '/CN=UN1CA Fork OTA/' -keyout "$KEY_TMP/private.pem" -out "$KEY_TMP/cert.pem" 2> "$KEY_TMP/generate.log"
openssl pkcs8 -topk8 -inform PEM -outform DER -nocrypt \
    -in "$KEY_TMP/private.pem" -out "$KEY_TMP/private.pk8"
cp "$KEY_TMP/private.pk8" security/unica_ota.pk8
cp "$KEY_TMP/cert.pem" security/unica_ota.x509.pem
echo "OTA key generated. Back it up securely; scripts/generate_ota_key.sh --help shows CI setup."
