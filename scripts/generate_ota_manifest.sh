#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Usage: generate_ota_manifest <zip directory> <HTTPS download base URL> [output]
SCRIPT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
exec python3 "$SCRIPT_ROOT/scripts/internal/ota_manifest.py" "$@"
