#!/usr/bin/env bash
# Собирает golos-asr под arm64 и x86_64, сливает в universal binary через lipo.
# Подписывает Developer ID, если задан APPLE_DEVELOPER_ID.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CRATE_DIR="$SCRIPT_DIR/.."
cd "$CRATE_DIR"

echo "==> Building golos-asr for aarch64-apple-darwin"
cargo build --release --target aarch64-apple-darwin

echo "==> Building golos-asr for x86_64-apple-darwin"
cargo build --release --target x86_64-apple-darwin

OUT_DIR="$CRATE_DIR/target/universal-apple-darwin/release"
mkdir -p "$OUT_DIR"

echo "==> Lipo-ing into $OUT_DIR/golos-asr"
lipo -create \
    -output "$OUT_DIR/golos-asr" \
    "$CRATE_DIR/target/aarch64-apple-darwin/release/golos-asr" \
    "$CRATE_DIR/target/x86_64-apple-darwin/release/golos-asr"

if [[ -n "${APPLE_DEVELOPER_ID:-}" ]]; then
    echo "==> Code-signing with: $APPLE_DEVELOPER_ID"
    codesign --force --options runtime --timestamp \
        --sign "$APPLE_DEVELOPER_ID" \
        "$OUT_DIR/golos-asr"
    codesign --verify --strict --verbose=2 "$OUT_DIR/golos-asr"
fi

echo "==> Done."
file "$OUT_DIR/golos-asr"
