import Foundation

@MainActor
final class DictationCoordinator: ObservableObject {
    enum State: Equatable {
        case idle
        case preparing(mode: Mode)
        case recording(mode: Mode, startedAt: Date)
        case transcribing
        case error(message: String)
    }
    enum Mode: Equatable { case ptt, toggle }

    @Published private(set) var state: State = .idle
    @Published private(set) var lastError: String? = nil

    private let provider: TranscriptionProvider
    private let injector: TextInjector
    private let minSessionMs: Int

    init(provider: TranscriptionProvider, injector: TextInjector, minSessionMs: Int = 200) {
        self.provider = provider
        self.injector = injector
        self.minSessionMs = minSessionMs
    }

    /// Поднять provider и загрузить модель.
    func warmup(modelDir: URL) async throws {
        try await provider.start(modelDir: modelDir)
    }

    /// Немедленно возвращает координатор в .idle и отменяет текущий provider.
    func cancelToIdle() {
        state = .idle
        Task { await provider.cancel() }
    }

    /// Шлёт PCM-сэмплы в провайдер во время recording или preparing.
    func feed(samples: Data) {
        switch state {
        case .recording, .preparing: break
        default: return
        }
        try? provider.feed(samples: samples)
    }

    /// Главный entry для входящих событий.
    func handle(_ event: HotkeyEvent) {
        switch (state, event) {
        case (.idle, .pttPressed):
            startRecording(mode: .ptt)
        case (.recording(.ptt, _), .pttReleased):
            finishRecording()
        case (.idle, .toggleTriggered):
            startRecording(mode: .toggle)
        case (.recording(.toggle, _), .toggleTriggered):
            finishRecording()
        case (.preparing(.ptt), .pttReleased):
            // beginSession ещё в полёте — отменяем session preparation.
            state = .idle
            Task { await provider.cancel() }
        case (.preparing(.toggle), .toggleTriggered):
            state = .idle
            Task { await provider.cancel() }
        default:
            Log.coordinator.warning("ignoring \(String(describing: event), privacy: .public) in \(String(describing: self.state), privacy: .public)")
        }
    }

    private func startRecording(mode: Mode) {
        let started = Date()
        // Синхронно: state + reset счётчика, ДО любых async hops. Иначе tap-данные
        // с микрофона могут попасть в feed() ещё до reset'а в beginSession Task.
        state = .preparing(mode: mode)
        provider.resetSampleCounter()
        Task {
            do {
                try await provider.beginSession()
                // Защита от race: пока beginSession был в полёте, user мог отпустить
                // хоткей и state ушёл в .idle/.transcribing/.error — нельзя
                // перезаписывать поверх.
                if case .preparing(let m) = self.state {
                    self.state = .recording(mode: m, startedAt: started)
                    Sounds.recordStart()
                }
            } catch {
                if case .preparing = self.state {
                    self.state = .error(message: error.localizedDescription)
                    self.lastError = error.localizedDescription
                }
            }
        }
    }

    private func finishRecording() {
        guard case .recording(_, let started) = state else { return }
        let duration = Int(Date().timeIntervalSince(started) * 1000)
        if duration < minSessionMs {
            state = .idle
            Task { await provider.cancel() }
            return
        }
        Sounds.recordStop()
        state = .transcribing
        Task {
            do {
                Log.coordinator.info("finalizing — flushing samples")
                await provider.flushSamples()
                Log.coordinator.info("finalizing — calling sidecar")
                let result = try await provider.finalize()
                Log.coordinator.info("got transcript: '\(result.text, privacy: .public)' (\(result.durationMs, privacy: .public)ms)")
                if AppSettings.shared.historyEnabled, !result.text.isEmpty {
                    let days = AppSettings.shared.historyRetentionDays
                    Task {
                        await HistoryStore.shared.add(text: result.text, date: Date())
                        await HistoryStore.shared.prune(retentionDays: days, now: Date())
                    }
                }
                let outcome = await injector.inject(text: result.text)
                Log.coordinator.info("inject outcome: \(String(describing: outcome), privacy: .public)")
                if case .copiedToClipboard = outcome {
                    Notifications.show(title: L10n.notifClipboard, body: L10n.notifClipboardBody)
                }
                self.state = .idle
            } catch {
                Log.coordinator.error("finalize/inject failed: \(error.localizedDescription, privacy: .public)")
                self.state = .error(message: error.localizedDescription)
                self.lastError = error.localizedDescription
                // Авто-вернуться в idle через 3 сек.
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                if case .error = self.state { self.state = .idle }
            }
        }
    }
}
