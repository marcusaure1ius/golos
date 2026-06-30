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

    @Published private(set) var permissionIssue: String?

    private var didStart = false
    private var hotkeysRunning = false

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

        // Apply audio settings
        audio.applySettings(
            deviceUid: AppSettings.shared.deviceUid,
            voiceProcessingEnabled: AppSettings.shared.noiseReduction
        )

        // Hotkeys (требуют Input Monitoring). Создаём всегда; tap поднимаем когда
        // доступ выдан — на свежей установке он выдаётся в онбординге уже ПОСЛЕ старта.
        self.hotkeys = HotkeyManager(
            holdThresholdMs: AppSettings.shared.holdMs,
            doubleTapWindowMs: AppSettings.shared.doubleTapMs,
            boundKeycode: Int64(AppSettings.shared.hotkeyKeycode)
        ) { [weak self] e in
            self?.dictation.handle(e)
        }
        startHotkeysIfNeeded()

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

        // Warmup модели если она установлена; иначе onboarding скачает и прогреет.
        Task { @MainActor [weak self] in await self?.warmupModelIfAvailable() }

        // Onboarding на первом запуске
        if AppSettings.shared.firstRun {
            openOnboarding()
        }
    }

    /// Поднимает хоткей-tap, если Input Monitoring выдан и tap ещё не запущен.
    /// Зовётся при старте И когда доступ выдаётся позже в онбординге — иначе на
    /// свежей установке правый ⌥ остаётся мёртвым (tap не пересоздавался).
    func startHotkeysIfNeeded() {
        guard !hotkeysRunning, let hm = hotkeys else { return }
        guard Permissions.inputMonitoringGranted() else {
            Log.coordinator.info("hotkeys: awaiting Input Monitoring")
            return
        }
        do {
            try hm.start()
            hotkeysRunning = true
            permissionIssue = nil
            Log.coordinator.info("hotkeys started")
        } catch {
            Log.coordinator.error("hotkeys start failed: \(error.localizedDescription, privacy: .public)")
            permissionIssue = "Хоткеи отключены: \(error.localizedDescription). Открыть System Settings → Input Monitoring."
        }
    }

    /// Грузит модель в sidecar и прогревает аудио, если модель уже скачана.
    /// Идемпотентно (warmup сам по себе идемпотентен). Зовётся при старте и
    /// после скачивания модели в онбординге.
    func warmupModelIfAvailable() async {
        let dir = AppPaths.modelDir(ModelDescriptor.gigaam.id)
        guard FileManager.default.fileExists(atPath: dir.appendingPathComponent("model.onnx").path) else {
            Log.coordinator.info("model not installed; awaiting onboarding")
            return
        }
        do {
            try await dictation.warmup(modelDir: dir)
            Log.coordinator.info("warmup succeeded for \(ModelDescriptor.gigaam.id, privacy: .public)")
            // Прогрев Voice Processing AU — иначе первый start() блокирует MainActor 2-3s.
            audio.prewarm()
        } catch {
            Log.coordinator.error("warmup failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func applyState(_ state: DictationCoordinator.State) {
        switch state {
        case .idle:
            pill.hide()
            menuBar?.setState(.idle)
            audio.stop()
        case .preparing(let mode):
            do { try audio.start() } catch {
                Log.coordinator.error("audio start failed: \(error.localizedDescription, privacy: .public)")
                permissionIssue = "Микрофон недоступен: \(error.localizedDescription). Открыть System Settings → Конфиденциальность → Микрофон."
                dictation.cancelToIdle()
                return
            }
            pill.viewModel.resetHistory()
            pill.viewModel.state = .recording(mode: mode)
            pill.show()
            menuBar?.setState(.recording)
        case .recording(let mode, _):
            do { try audio.start() } catch {
                Log.coordinator.error("audio start failed: \(error.localizedDescription, privacy: .public)")
                permissionIssue = "Микрофон недоступен: \(error.localizedDescription). Открыть System Settings → Конфиденциальность → Микрофон."
                dictation.cancelToIdle()
                return
            }
            pill.viewModel.resetHistory()
            pill.viewModel.state = .recording(mode: mode)
            pill.show()
            menuBar?.setState(.recording)
        case .transcribing:
            audio.stop()
            pill.viewModel.state = .transcribing
            menuBar?.setState(.processing)
        case .error(let msg):
            audio.stop()
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
