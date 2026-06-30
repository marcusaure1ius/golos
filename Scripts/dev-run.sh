#!/usr/bin/env bash
# Собирает golos с подписью golos-dev, переустанавливает в ~/Applications и запускает.
# Запускать в своей GUI-сессии (нужен доступ к keychain для codesign):
#   bash Scripts/dev-run.sh
set -euo pipefail
cd "$(dirname "$0")/.."

DERIVED=/tmp/golos-fix
APP="$DERIVED/Build/Products/Debug/golos.app"
SIDECAR=golos-asr/target/universal-apple-darwin/release/golos-asr

if [[ ! -f "$SIDECAR" ]]; then
  echo "▶ Sidecar не собран — собираю Rust…"
  PATH="$HOME/.cargo/bin:$PATH" bash golos-asr/scripts/build-universal.sh
fi

echo "▶ Сборка (подпись golos-dev)…"
xcodebuild build -project golos.xcodeproj -scheme golos -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath "$DERIVED" | tail -3

echo "▶ Подпись app:"
codesign -dvvv "$APP" 2>&1 | grep -iE "Authority|Signature" || true

echo "▶ Переустановка в ~/Applications…"
pkill golos 2>/dev/null || true
sleep 1
rm -rf "$HOME/Applications/golos.app"
cp -R "$APP" "$HOME/Applications/golos.app"

echo "▶ Запуск…"
open "$HOME/Applications/golos.app"
echo "✅ Готово — golos подписан golos-dev и запущен."
