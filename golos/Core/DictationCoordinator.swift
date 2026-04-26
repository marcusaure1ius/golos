import Foundation

@MainActor
final class DictationCoordinator: ObservableObject {
    enum State: Equatable {
        case idle
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

    /// Шлёт PCM-сэмплы в провайдер во время recording.
    func feed(samples: Data) {
        guard case .recording = state else { return }
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
        default:
            Log.coordinator.warning("ignoring \(String(describing: event), privacy: .public) in \(String(describing: self.state), privacy: .public)")
        }
    }

    private func startRecording(mode: Mode) {
        state = .recording(mode: mode, startedAt: Date())
        Task {
            do {
                try await provider.beginSession()
            } catch {
                self.state = .error(message: error.localizedDescription)
                self.lastError = error.localizedDescription
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
        state = .transcribing
        Task {
            do {
                let result = try await provider.finalize()
                _ = await injector.inject(text: result.text)
                self.state = .idle
            } catch {
                self.state = .error(message: error.localizedDescription)
                self.lastError = error.localizedDescription
                // Авто-вернуться в idle через 3 сек.
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                if case .error = self.state { self.state = .idle }
            }
        }
    }
}
