import SwiftUI

struct DemoStep: View {
    @Environment(\.palette) var p
    @EnvironmentObject private var coordinator: AppCoordinator
    @ObservedObject var vm: OnboardingViewModel
    @State private var text: String = ""
    @State private var levels: [Float] = []
    @State private var failed = false
    @State private var armed = false

    private var recording: Bool {
        if case .recording = coordinator.dictation.state { return true }
        return false
    }

    var body: some View {
        StepLayout(
            icon: "mic",
            title: failed ? "Почти!" : (text.isEmpty ? (recording ? "Слушаю…" : "Попробуй прямо сейчас")
                                                       : "Получилось!"),
            subtitle: failed
                ? "Текст распознан, но вставить не удалось — проверь Универсальный доступ."
                : (text.isEmpty ? "Зажми правый ⌥ Option, продиктуй любую фразу и отпусти. Текст появится здесь."
                                : "Это и есть весь Golos. Закрой окно — и диктуй в любом приложении точно так же.")
        ) {
            VStack(alignment: .leading, spacing: 12) {
                if recording {
                    HStack(spacing: 12) {
                        WaveformView(levels: levels, live: true, maxHeight: 40)
                        Text("● Запись").font(.system(size: 12, weight: .semibold)).foregroundStyle(p.muted)
                    }
                } else if !text.isEmpty && !failed {
                    Label("Текст вставлен", systemImage: "checkmark.circle")
                        .font(.system(size: 13.5))
                        .foregroundStyle(p.ink)
                        .transition(.opacity)
                } else {
                    HStack(spacing: 12) {
                        KeyCap()
                        Text("Зажми правый ⌥ и говори")
                            .font(.system(size: 11.5))
                            .foregroundStyle(p.muted)
                    }
                }

                DemoField(text: $text)

                if failed {
                    Button("Назад к Универсальному доступу") { vm.go(to: 3) }
                        .buttonStyle(GhostButton())
                }
            }
        }
        .onChange(of: recording) { isRecording in
            if isRecording { levels = []; armed = true }
        }
        .onReceive(coordinator.audio.$level) { lvl in
            guard recording else { return }
            levels.append(lvl)
            if levels.count > 32 { levels.removeFirst(levels.count - 32) }
        }
        .onReceive(coordinator.dictation.$lastOutcome.compactMap { $0 }) { outcome in
            guard armed else { return }
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
    @Environment(\.palette) var p
    @Binding var text: String
    @FocusState private var focused: Bool
    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                // Выровнено с местом, где TextEditor рисует текст/каретку
                // (padding 8 + ~5 lineFragmentPadding по горизонтали).
                Text("Здесь появится твой текст…")
                    .foregroundStyle(p.muted2)
                    .padding(.leading, 13).padding(.top, 8)
                    .allowsHitTesting(false)
            }
            TextEditor(text: $text)
                .scrollContentBackground(.hidden)
                .padding(8)
                .focused($focused)
                .foregroundStyle(p.ink)
        }
        .frame(minHeight: 110)
        .background(p.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(p.fieldBorder, lineWidth: 1)
        )
        // Сразу фокус на поле — чтобы вставка попадала именно сюда и каретка была видна.
        .onAppear { DispatchQueue.main.async { focused = true } }
    }
}

/// Клавиша ⌥ для подсказки.
private struct KeyCap: View {
    @Environment(\.palette) var p
    var body: some View {
        VStack(spacing: 3) {
            Text("⌥").font(.system(size: 22, weight: .medium)).foregroundStyle(p.ink)
            Text("OPTION").font(.system(size: 9, weight: .semibold)).foregroundStyle(p.muted).tracking(0.5)
        }
        .frame(width: 56, height: 56)
        .background(p.selection, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(p.border, lineWidth: 1)
        )
    }
}
