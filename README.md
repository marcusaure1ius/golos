# Golos

**Локальная голосовая диктовка для macOS в стиле Wispr Flow.**
Зажми горячую клавишу, скажи фразу — и текст появится в активном приложении.
Звук не покидает твой Mac: распознавание полностью локальное,
на [GigaAM-v3](https://github.com/salute-developers/GigaAM) (ONNX).

[![CI](https://github.com/marcusaure1ius/golos/actions/workflows/ci.yml/badge.svg)](https://github.com/marcusaure1ius/golos/actions/workflows/ci.yml)
[![Релиз](https://img.shields.io/github/v/release/marcusaure1ius/golos?style=flat&label=релиз)](https://github.com/marcusaure1ius/golos/releases/latest)
![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue?style=flat&logo=apple)
![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-arm64-orange?style=flat)
![Swift](https://img.shields.io/badge/Swift-5.9-F05138?style=flat&logo=swift&logoColor=white)
![Rust](https://img.shields.io/badge/Rust-sidecar-DEA584?style=flat&logo=rust&logoColor=white)
[![Лицензия MIT](https://img.shields.io/badge/лицензия-MIT-green?style=flat)](LICENSE)

## Демо

Пока говоришь, на экране висит небольшая плашка с живой звуковой волной.
Отпустил клавишу — и текст уже вставлен в активное приложение:

![Запись в golos](assets/pill.png)

Каждая диктовка сохраняется в историю с поиском:

![История golos](assets/history.png)

Окно настроек:

![Настройки golos](assets/settings.png)

## Как это работает

Swift-приложение отвечает за интерфейс, горячую клавишу, захват звука и
вставку текста. Само распознавание выполняет небольшой вспомогательный
процесс на Rust — сайдкар `golos-asr`. Между собой они общаются по
JSON-lines через stdin/stdout, а звук передаётся через named FIFO.

```
клавиша → запись → распознавание (GigaAM-v3, ONNX) → текст → вставка
```

## Установка

Готовый DMG — на [странице релизов](https://github.com/marcusaure1ius/golos/releases/latest).
Пошаговая инструкция (включая обход Gatekeeper — приложение не подписано
через Apple): [INSTALL.md](INSTALL.md).

## Требования

- macOS 13 (Ventura) или новее
- **Apple Silicon** — Intel (x86_64) не поддерживается (у зависимости `ort`
  нет prebuilt ONNX Runtime под x86_64)
- Для сборки из исходников: Xcode 15+ и [Rust toolchain](https://rustup.rs/)
- Модель распознавания скачивается при первом запуске
  (см. [Модель распознавания](#модель-распознавания))

## Сборка из исходников

Сайдкар **не** собирается Xcode — сначала собери его, потом приложение:

```bash
# 1. Собрать Rust-сайдкар
bash golos-asr/scripts/build-universal.sh

# 2. Собрать приложение (Xcode копирует уже собранный сайдкар в bundle)
xcodebuild build -project golos.xcodeproj -scheme golos \
  -configuration Debug -destination 'platform=macOS'
```

Изменил `golos-asr/src/*.rs` — пересобери сайдкар до пересборки приложения.

## Первый запуск

Онбординг проведёт по шагам:

1. **Микрофон** — чтобы слышать речь
2. **Универсальный доступ** — для глобального хоткея и вставки текста
3. **Мониторинг ввода** — для отслеживания хоткея
4. **Загрузка модели** — скачиваются ONNX-веса GigaAM-v3

Дальше: зажми горячую клавишу (по умолчанию — **правый Option**), скажи
фразу, отпусти — текст вставится в активное приложение.

## Тесты

```bash
# Rust (сайдкар)
cargo test

# Swift
xcodebuild test -project golos.xcodeproj -scheme golos \
  -destination 'platform=macOS'
```

## Модель распознавания

Веса GigaAM-v3 **не** лежат в репозитории — они скачиваются при первом
запуске.

- Модель GigaAM-v3 опубликована **SaluteDevices** (Сбер) под лицензией
  **MIT** (с декабря 2024) — коммерческое использование, распространение и
  дообучение разрешены при сохранении атрибуции.
  Источник: [salute-developers/GigaAM](https://github.com/salute-developers/GigaAM).
- Веса скачиваются в формате **ONNX** из сторонней конверсии
  [istupakov/gigaam-v3-onnx](https://huggingface.co/istupakov/gigaam-v3-onnx),
  тоже MIT с атрибуцией оригинала.

## Лицензия

golos распространяется под [лицензией MIT](LICENSE).

Сторонние компоненты (ONNX Runtime, Rust-крейты) и их лицензии перечислены
в [THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md). Все — пермиссивные
(семейство MIT / Apache-2.0).
