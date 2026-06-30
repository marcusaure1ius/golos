# golos-asr

Sidecar binary для приложения [Golos](../README.md). Транскрибирует аудио через
GigaAM-v3 ONNX, общается с родительским процессом по JSON-lines протоколу.

## Сборка

```bash
# Локально под текущую архитектуру:
cargo build --release

# Apple Silicon release с подписью (если задан APPLE_DEVELOPER_ID):
./scripts/build-universal.sh
```

> Intel Mac (x86_64) не поддерживается — `ort-sys` (через `transcribe-rs`) не
> поставляет prebuilt ONNX Runtime под x86_64.

## Запуск

```bash
golos-asr --audio-path <path>
```

`--audio-path` — путь к named FIFO (или файлу), из которого sidecar читает сырые
сэмплы: **Int16 LE, 16 kHz, mono**. Control-сообщения идут по stdin, ответы — по
stdout (оба JSON-lines).

Хендшейк: `hello` → `load` → `ready` → `begin_session` → (PCM в FIFO) →
`end_session` → `final`.

## Протокол

Каждое сообщение — одна JSON-строка (`\n`-разделитель). Запросы несут `id`
(request_id) для корреляции с ответом.

**stdin (Request):**

| `type`           | поля                       | описание                                   |
|------------------|----------------------------|--------------------------------------------|
| `load`           | `id`, `model_path`         | загрузить ONNX-bundle GigaAM-v3 (один раз) |
| `begin_session`  | `id`                       | начать запись (audio идёт через FIFO)      |
| `end_session`    | `id`, `samples_total`      | финализировать, ждать `final`              |
| `cancel`         | `id`                       | прервать сессию без транскрипции           |
| `shutdown`       | `id`                       | graceful shutdown                          |

**stdout (Response):**

| `type`            | поля                            | описание                                |
|-------------------|---------------------------------|-----------------------------------------|
| `hello`           | `version`                       | сразу после старта (без `id`)           |
| `ready`           | `id`                            | модель загружена                        |
| `session_started` | `id`                            | сессия начата                           |
| `final`           | `id`, `text`, `duration_ms`     | финальный transcript                    |
| `cancelled`       | `id`                            | подтверждение `cancel`                  |
| `error`           | `id?`, `kind`, `message`        | ошибка (`id` отсутствует при ошибке JSON-парсинга) |

**stderr:** логи (уровень через `GOLOS_ASR_LOG`, формат `tracing-subscriber`
env_filter — например `GOLOS_ASR_LOG=debug`).

## Тесты

```bash
cargo test --lib                                       # unit-тесты (без модели)
GOLOS_ASR_MODEL_DIR=/path/to/giga-am-v3 cargo test     # включая e2e (требует ONNX-bundle + fixture WAV)
```

## Зависимости

См. `Cargo.toml`. Ключевое: `transcribe-rs 0.3` (feature `onnx`) поверх ONNX
Runtime. Веса GigaAM-v3 не входят в репозиторий — скачиваются Swift-приложением
на первом запуске (см. корневой README).
