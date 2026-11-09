#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later

# Populate the wrapper's own cache with a verified official distribution before
# Java runs. curl retries transient HTTP failures independently of the wrapper.
set -euo pipefail

PROPERTIES="${1:-gradle/wrapper/gradle-wrapper.properties}"
URL=""
BASE="GRADLE_USER_HOME"
DIST_PATH="wrapper/dists"
EXPECTED=""
while IFS= read -r LINE || [ -n "$LINE" ]; do
    LINE="${LINE%$'\r'}"
    case "$LINE" in
        distributionUrl=*) URL="${LINE#*=}" ;;
        distributionBase=*) BASE="${LINE#*=}" ;;
        distributionPath=*) DIST_PATH="${LINE#*=}" ;;
        distributionSha256Sum=*) EXPECTED="${LINE#*=}" ;;
    esac
done < "$PROPERTIES"
URL="${URL//\\:/:}"

if [[ "$BASE" != "GRADLE_USER_HOME" ]] || \
        [[ ! "$URL" =~ ^https://(services|downloads)\.gradle\.org/distributions/(gradle-[0-9][A-Za-z0-9.-]*-(bin|all)\.zip)$ ]]; then
    echo "Unsupported Gradle wrapper distribution settings" >&2
    exit 1
fi
NAME="${BASH_REMATCH[2]}"

# Match Gradle PathAssembler: unsigned MD5 of the original URL, in base 36.
HASH="$(printf '%s' "$URL" | md5sum)"
HASH="${HASH%% *}"
ENCODED="$(BC_LINE_LENGTH=0 bc <<< "obase=36; ibase=16; ${HASH^^}")"
read -r -a DIGITS <<< "$ENCODED"
ALPHABET="0123456789abcdefghijklmnopqrstuvwxyz"
KEY=""
for DIGIT in "${DIGITS[@]}"; do
    KEY+="${ALPHABET:$((10#$DIGIT)):1}"
done
CACHE="${GRADLE_USER_HOME:-$HOME/.gradle}/$DIST_PATH/${NAME%.zip}/$KEY"
ZIP="$CACHE/$NAME"

if [ -f "$ZIP.ok" ] && [ -x "$CACHE/${NAME%-*}/bin/gradle" ]; then
    exit 0
fi

mkdir -p "$CACHE"
CURL=(curl --fail --location --silent --show-error --retry 4 --retry-all-errors
      --retry-delay 3 --connect-timeout 15 --max-time 300)
if [ -z "$EXPECTED" ]; then
    EXPECTED="$("${CURL[@]}" "https://downloads.gradle.org/distributions/$NAME.sha256")"
fi
if [[ ! "$EXPECTED" =~ ^[[:xdigit:]]{64}$ ]]; then
    echo "Invalid official checksum for $NAME" >&2
    exit 1
fi

if [ -f "$ZIP" ] && printf '%s  %s\n' "$EXPECTED" "$ZIP" | sha256sum --check --status; then
    exit 0
fi

echo "Downloading and verifying $NAME with curl..."
PART="$(mktemp "$CACHE/$NAME.part.XXXXXXXX")"
trap 'test ! -f "$PART" || unlink "$PART"' EXIT
"${CURL[@]}" "https://downloads.gradle.org/distributions/$NAME" --output "$PART"
printf '%s  %s\n' "$EXPECTED" "$PART" | sha256sum --check
mv -f "$PART" "$ZIP"
