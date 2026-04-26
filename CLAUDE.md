# CLAUDE.md

## Project

`golos` — нативное macOS-приложение для голосовой диктовки в стиле Wispr Flow, с локальным распознаванием через GigaAM-v3 (ONNX). Хоткей (по умолчанию Right Option) → запись → транскрипция → вставка текста в активное приложение.

## Architecture

Swift app + Rust sidecar.

- **Swift app** (`golos/`) — UI, hotkeys, audio capture, paste injection, settings, onboarding.
  - `Core/` — состояние и движок (`DictationCoordinator`, `AudioCapture`, `AudioWriter`, `LocalGigaAMProvider`, `HotkeyManager`, `ClipboardPasteInjector`, `ModelManager`).
  - `Core/SidecarProtocol.swift` — JSON-lines протокол со sidecar (request_id, samples_total handshake).
  - `UI/` — Menu bar, Pill (recording overlay), Settings, Onboarding.
  - `Util/` — `Logger` (`os.Logger` subsystem `com.golos.app`), `Permissions`, `AppPaths`, `AudioDevices`.
- **Rust sidecar** (`golos-asr/`) — ONNX inference. Получает control сообщения по stdin (JSON-lines), PCM (Int16 LE 16kHz mono) по отдельному audio-fd pipe, отвечает по stdout.

IPC handshake: Hello → Load{model_path} → Ready → BeginSession → feed PCM → EndSession{samples_total} → Final{text}.

## Code conventions

- Swift 5.9+, macOS 13+. `@MainActor` для UI и большинства Core-классов; `actor` для serialized state (`AudioWriter`, `ResponseCorrelator`).
- Тесты: **Swift Testing** (`@Suite`/`@Test`/`#expect`) для unit, XCTest для UI (`golosUITests`). Не путать.
- Существующие комментарии и user-facing строки — на русском. Сохраняй стиль.
- Логи через `Log.<category>` (см. `Util/Logger.swift`), категории: `coordinator`, `hotkeys`, `audio`, `sidecar`, `injection`, `model`, `ui`.
- Spec-документы и планы лежат локально в `docs/specs/` и `docs/plans/` (gitignored), не комить туда.

## Build & test

- Rust tests: `/Users/alfa/.cargo/bin/cargo test` — `cargo` не в default PATH.
- Swift tests: `xcodebuild test -project golos.xcodeproj -scheme golos -destination 'platform=macOS' -derivedDataPath /tmp/golos-derived`.
- Подсчёт тестов: `xcodebuild test ... > /tmp/log; grep -c "passed on" /tmp/log` — `| tail` обрезает Rust'овые `test result:` строки.
- **Sidecar пересобирается отдельно**: `PATH=/Users/alfa/.cargo/bin:$PATH bash golos-asr/scripts/build-universal.sh`. `xcodebuild` сам не запускает cargo — `Scripts/copy-sidecar.sh` копирует уже-собранный бинарь. Если изменился `golos-asr/src/*.rs` — сначала собрать Rust, потом app.
- Build app: `xcodebuild build -project golos.xcodeproj -scheme golos -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/golos-fix`.

## Behavioral reminders

Generic guidelines, без которых типичные ошибки повторяются:

1. **Think first.** State assumptions, ask if unclear, don't pick silently between interpretations.
2. **Minimum code.** Никаких speculative фич, абстракций под одно использование, error-handling под impossible сценарии.
3. **Surgical edits.** Меняй только то, что нужно. Не "улучшай" соседний код. Сохраняй существующий стиль, даже если сделал бы иначе.
4. **TDD where it makes sense.** Для bugfix — тест-репро сначала; для feature — тесты вокруг success criteria. Не тестируй то, что и так очевидно из кода.
5. **Verify with tests.** После изменений — прогон обоих сьютов (Rust + Swift). Уменьшение test count = регрессия.
