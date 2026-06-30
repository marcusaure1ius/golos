import SwiftUI

struct DemoStep: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @ObservedObject var vm: OnboardingViewModel
    @State private var text: String = ""
    @State private var levels: [Float] = []
    @State private var failed = false

    private var recording: Bool {
        if case .recording = coordinator.dictation.state { return true }
        return false
    }

    var body: some View {
        StepLayout(
            iconColors: failed ? [.orange, .yellow] : (text.isEmpty ? [.teal, .cyan] : [.green, .mint]),
            icon: "mic.fill",
            title: failed ? "Почти!" : (text.isEmpty ? (recording ? "Слушаю…" : "Попробуй прямо сейчас")
                                                       : "Получилось! 🎉"),
            subtitle: failed
                ? "Текст распознан, но вставить не удалось — проверь Универсальный доступ."
                : (text.isEmpty ? "Зажми правый ⌥ Option, продиктуй любую фразу и отпусти. Текст появится здесь."
                                : "Это и есть весь Golos. Закрой окно — и диктуй в любом приложении точно так же.")
        ) {
            // scene
            if recording {
                VStack(spacing: 12) {
                    WaveformView(levels: levels, live: true, maxHeight: 88)
                    Text("● Запись").font(.system(size: 12, weight: .semibold)).foregroundStyle(.red)
                }
            } else if !text.isEmpty && !failed {
                VStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 54)).foregroundStyle(.green)
                    Text("Текст вставлен").font(.system(size: 12, weight: .semibold)).foregroundStyle(.green)
                }.transition(.scale.combined(with: .opacity))
            } else {
                VStack(spacing: 14) {
                    KeyCap()
                    Text("Зажми правый ⌥ и говори").font(.system(size: 11.5)).foregroundStyle(.secondary)
                }
            }
        } content: {
            VStack(alignment: .leading, spacing: 10) {
                DemoField(text: $text)
                if failed {
                    Button("Назад к Универсальному доступу") { vm.currentStep = 3 }
                        .buttonStyle(.bordered)
                }
            }
        }
        .onChange(of: recording) { isRecording in
            if isRecording { levels = [] }
        }
        .onReceive(coordinator.audio.$level) { lvl in
            guard recording else { return }
            levels.append(lvl)
            if levels.count > 32 { levels.removeFirst(levels.count - 32) }
        }
        .onReceive(coordinator.dictation.$lastOutcome.compactMap { $0 }) { outcome in
            // Пустой транскрипт — игнорируем, не праздновать и не показывать фоллбэк.
            guard !outcome.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                switch outcome.outcome {
                case .injected:
                    // Текст вставился реально; окно онбординга фронтовое —
                    // дублируем в поле, чтобы гарантированно показать.
                    if text.isEmpty { text = outcome.text }
                    failed = false
                case .copiedToClipboard, .failed:
                    text = outcome.text
                    failed = true
                }
            }
        }
    }
}

/// Демо-поле ввода (фокус-таргет для реальной вставки).
private struct DemoField: View {
    @Binding var text: String
    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text("Здесь появится твой текст…").foregroundStyle(.secondary).padding(14)
            }
            TextEditor(text: $text).scrollContentBackground(.hidden).padding(8)
        }
        .frame(minHeight: 110)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.secondary.opacity(0.25), lineWidth: 1))
    }
}

/// Клавиша ⌥ для подсказки.
private struct KeyCap: View {
    var body: some View {
        VStack(spacing: 3) {
            Text("⌥").font(.system(size: 24, weight: .medium))
            Text("OPTION").font(.system(size: 9, weight: .semibold)).foregroundStyle(.secondary).tracking(0.5)
        }
        .frame(width: 64, height: 64)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.secondary.opacity(0.2), lineWidth: 1))
        .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
    }
}
