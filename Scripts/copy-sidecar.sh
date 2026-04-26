#!/usr/bin/env bash
# Копирует свежесобранный golos-asr binary в .app bundle.
# Запускается как Run Script Build Phase в Xcode.

set -euo pipefail

SIDECAR_SRC="${PROJECT_DIR}/golos-asr/target/universal-apple-darwin/release/golos-asr"
DEST_DIR="${BUILT_PRODUCTS_DIR}/${EXECUTABLE_FOLDER_PATH}"

if [[ ! -f "$SIDECAR_SRC" ]]; then
    echo "error: golos-asr binary not found at $SIDECAR_SRC"
    echo "       run ./golos-asr/scripts/build-universal.sh first"
    exit 1
fi

mkdir -p "$DEST_DIR"
cp -f "$SIDECAR_SRC" "$DEST_DIR/golos-asr"
chmod +x "$DEST_DIR/golos-asr"

# Code-sign с тем же identity, что и app, если задан CODE_SIGN_IDENTITY.
if [[ -n "${EXPANDED_CODE_SIGN_IDENTITY:-}" && "${EXPANDED_CODE_SIGN_IDENTITY}" != "-" ]]; then
    codesign --force --options runtime --timestamp \
        --sign "${EXPANDED_CODE_SIGN_IDENTITY}" \
        "$DEST_DIR/golos-asr"
fi

echo "Sidecar copied to $DEST_DIR/golos-asr"
