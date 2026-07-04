import Foundation

/// Источник транскрипции. В MVP единственная реализация — локальный sidecar.
/// Архитектурно protocol позволяет позже добавить cloud-провайдеры.
protocol TranscriptionProvider: AnyObject {
    /// Запустить провайдера (например, sidecar) и загрузить указанную модель.
    func start(modelDir: URL) async throws

    /// Сбросить счётчик samples нового сессии. Синхронный — вызывать ДО beginSession,
    /// иначе tap-данные с микрофона могут уйти в счётчик раньше reset'а.
    func resetSampleCounter()

    /// Начать новую сессию записи — после этого вызовы `feed` будут учтены.
    /// `biasTerms` — слова для contextual biasing (правильные написания из словаря).
    func beginSession(biasTerms: [String]) async throws

    /// Прокачать сэмплы 16kHz mono Int16 PCM (little-endian).
    /// Семантика — non-blocking: данные кладутся в выходной буфер.
    func feed(samples: Data) throws

    /// Дождаться что все ранее feed'нутые семплы попали в transport.
    func flushSamples() async

    /// Закончить запись и дождаться финального transcript.
    func finalize() async throws -> Transcript

    /// Отменить текущую сессию (если есть).
    func cancel() async

    /// Завершить провайдера (graceful).
    func shutdown() async

    /// Stream партиалов; в MVP может не выдавать ничего.
    var partials: AsyncStream<String> { get }
}

struct Transcript: Equatable {
    let text: String
    let durationMs: UInt64
}

enum TranscriptionError: Error, Equatable {
    case sidecarNotRunning
    case modelLoadFailed(String)
    case transcribeFailed(String)
    case timeout
    case protocolError(String)
}
