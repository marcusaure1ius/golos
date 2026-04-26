import AppKit
import SwiftUI

/// Корневой объект, который держит все singleton-сервисы и связывает их.
@MainActor
final class AppCoordinator: ObservableObject {
    let provider: LocalGigaAMProvider
    let injector: ClipboardPasteInjector
    let dictation: DictationCoordinator
    let audio = AudioCapture()
    let pill = PillWindow()
    let modelManager = ModelManager()
    var hotkeys: HotkeyManager?
    var menuBar: MenuBarController?

    private var didStart = false

    init() {
        let prov = LocalGigaAMProvider()
        self.provider = prov
        let inj = ClipboardPasteInjector()
        self.injector = inj
        self.dictation = DictationCoordinator(provider: prov, injector: inj)
    }

    /// Запускает все системные компоненты. Идемпотентно — вызывать один раз.
    func start(openSettings: @escaping () -> Void, openOnboarding: @escaping () -> Void) {
        guard !didStart else { return }
        didStart = true

        // Menu bar
        let mb = MenuBarController(
            onOpenSettings: openSettings,
            onQuit: { NSApp.terminate(nil) }
        )
        mb.install()
        self.menuBar = mb

        // Hotkeys (требуют Input Monitoring; если permission нет — start() выкинет ошибку, мы её залогируем)
        let hm = HotkeyManager(
            holdThresholdMs: AppSettings.shared.holdMs,
            doubleTapWindowMs: AppSettings.shared.doubleTapMs
        ) { [weak self] e in
            self?.dictation.handle(e)
        }
        do {
            try hm.start()
            self.hotkeys = hm
        } catch {
            Log.coordinator.error("hotkeys start failed: \(error.localizedDescription, privacy: .public)")
        }

        // Audio samples → coordinator
        let audio = self.audio
        let dictation = self.dictation
        Task { @MainActor in
            for await samples in audio.samples {
                dictation.feed(samples: samples)
            }
        }

        // Audio level → pill
        Task { @MainActor [weak self] in
            guard let self else { return }
            for await level in self.audio.$level.values {
                self.pill.viewModel.appendLevel(level)
            }
        }

        // Coordinator state → UI
        Task { @MainActor [weak self] in
            guard let self else { return }
            for await state in self.dictation.$state.values {
                self.applyState(state)
            }
        }

        // Warmup модели если она установлена; иначе — открыть onboarding.
        let mode = AppSettings.shared.modelMode
        let dir = AppPaths.modelDir(mode.modelId)
        Task { @MainActor [weak self] in
            guard let self else { return }
            if FileManager.default.fileExists(atPath: dir.appendingPathComponent("model.onnx").path) {
                do {
                    try await self.dictation.warmup(modelDir: dir)
                    Log.coordinator.info("warmup succeeded for \(mode.modelId, privacy: .public)")
                } catch {
                    Log.coordinator.error("warmup failed: \(error.localizedDescription, privacy: .public)")
                }
            } else {
                Log.coordinator.info("model not installed; awaiting onboarding")
            }
        }

        // Onboarding на первом запуске
        if AppSettings.shared.firstRun {
            openOnboarding()
        }
    }

    private func applyState(_ state: DictationCoordinator.State) {
        switch state {
        case .idle:
            pill.hide()
            menuBar?.setState(.idle)
            audio.stop()
        case .recording(let mode, _):
            do { try audio.start() } catch {
                Log.coordinator.error("audio start failed: \(error.localizedDescription, privacy: .public)")
            }
            pill.viewModel.state = .recording(mode: mode)
            pill.show()
            menuBar?.setState(.recording)
        case .transcribing:
            audio.stop()
            pill.viewModel.state = .transcribing
            menuBar?.setState(.processing)
        case .error(let msg):
            pill.viewModel.state = .error(message: msg)
            menuBar?.setState(.error)
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                self?.pill.hide()
                self?.menuBar?.setState(.idle)
            }
        }
    }
}
