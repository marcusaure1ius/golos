#!/usr/bin/env bash
# Сброс онбординга для проверки флоу как на свежей установке:
# firstRun=true + удаление скачанной модели. Запускать при закрытом app.
set -euo pipefail
BUNDLE_ID="com.golos-app.golos"

pkill golos 2>/dev/null || true
sleep 1
defaults delete "$BUNDLE_ID" ui.firstRun 2>/dev/null || true
defaults delete "$BUNDLE_ID" ui.onboardingCompleted 2>/dev/null || true
defaults delete "$BUNDLE_ID" ui.onboardingSkipped 2>/dev/null || true
rm -rf "$HOME/Library/Application Support/golos/models/e2e_ctc" 2>/dev/null || true
echo "✅ Онбординг сброшен. Запусти app — откроется онбординг с нуля."
