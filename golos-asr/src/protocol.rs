use serde::{Deserialize, Serialize};
use std::path::PathBuf;

/// Сообщения от Swift app в sidecar (по stdin, JSON-lines).
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum Request {
    /// Загрузить модель из директории. Должно прийти один раз перед begin_session.
    Load { model_path: PathBuf },
    /// Начать новую сессию записи. Аудио идёт по audio-fd.
    BeginSession,
    /// Закончить сессию. Sidecar финализирует и шлёт Response::Final.
    EndSession { samples_total: u64 },
    /// Прервать текущую сессию без транскрипции.
    Cancel,
    /// Запросить graceful shutdown.
    Shutdown,
}

/// Сообщения от sidecar в Swift app (по stdout, JSON-lines).
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum Response {
    /// Sidecar поднялся и готов к Load.
    Hello { version: String },
    /// Модель загружена, можно начинать сессии.
    Ready,
    /// Сессия начата, sidecar читает audio-fd.
    SessionStarted,
    /// Партиал-транскрипт. В MVP не отправляется — зарезервировано на будущее.
    #[allow(dead_code)]
    Partial { text: String },
    /// Финальный transcript после end_session.
    Final { text: String, duration_ms: u64 },
    /// Сессия отменена (после Cancel).
    Cancelled,
    /// Любая ошибка. `kind` — машиночитаемый код, `message` — для логов.
    Error { kind: String, message: String },
}

impl Response {
    /// Сериализует и добавляет '\n' (JSON-lines convention).
    pub fn to_line(&self) -> String {
        let mut s = serde_json::to_string(self).expect("Response must serialize");
        s.push('\n');
        s
    }
}
