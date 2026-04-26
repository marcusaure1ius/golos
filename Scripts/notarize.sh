#!/usr/bin/env bash
set -euo pipefail
DMG="$1"
xcrun notarytool submit "$DMG" \
    --apple-id "$APPLE_ID" \
    --team-id "$TEAM_ID" \
    --password "$APP_SPECIFIC_PASSWORD" \
    --wait
xcrun stapler staple "$DMG"
