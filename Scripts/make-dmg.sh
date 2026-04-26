#!/usr/bin/env bash
set -euo pipefail
APP="$1"          # путь к golos.app
OUT="$2"          # путь к .dmg
VOLUME_NAME="${VOLUME_NAME:-golos}"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
cp -R "$APP" "$TMP/"
ln -s /Applications "$TMP/Applications"

hdiutil create -volname "$VOLUME_NAME" -srcfolder "$TMP" -ov -format UDZO "$OUT"
