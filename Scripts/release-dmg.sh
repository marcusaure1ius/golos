#!/usr/bin/env bash
# Собирает релизный DMG за один проход: Rust sidecar → Release-сборка app → .dmg.
# Запускать в своей GUI-сессии (нужен доступ к keychain для подписи golos-dev):
#   bash Scripts/release-dmg.sh [путь-к-выходному.dmg]
# По умолчанию DMG кладётся на Рабочий стол (~/Desktop/golos.dmg).
set -euo pipefail
cd "$(dirname "$0")/.."

OUT="${1:-$HOME/Desktop/golos.dmg}"
DERIVED=/tmp/golos-release
APP="$DERIVED/Build/Products/Release/golos.app"
SIDECAR=golos-asr/target/universal-apple-darwin/release/golos-asr

if [[ ! -f "$SIDECAR" ]]; then
  echo "▶ Sidecar не собран — собираю Rust…"
  PATH="$HOME/.cargo/bin:$PATH" bash golos-asr/scripts/build-universal.sh
fi

echo "▶ Release-сборка app (подпись golos-dev)…"
xcodebuild build -project golos.xcodeproj -scheme golos -configuration Release \
  -destination 'platform=macOS' -derivedDataPath "$DERIVED" | tail -3

echo "▶ Упаковка в DMG: $OUT"
bash Scripts/make-dmg.sh "$APP" "$OUT"

echo "✅ Готово: $OUT"
ls -lh "$OUT"
