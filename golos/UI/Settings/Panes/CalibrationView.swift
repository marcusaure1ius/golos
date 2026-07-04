import SwiftUI

/// Экран калибровки распознавания: пользователь читает заготовленные фразы, мы
/// сравниваем с эталоном и предлагаем добавить в словарь проблемные слова.
struct CalibrationView: View {
    @ObservedObject var session: CalibrationSession
    let coordinator: DictationCoordinator
    let onClose: () -> Void

    @Environment(\.palette) var p

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .frame(width: 560, height: 460)
        .background(p.content)
    }

    @ViewBuilder
    private var content: some View {
        switch session.phase {
        case .intro:    intro
        case .recording: recording
        case .results:  results
        }
    }

    // MARK: - Интро

    private var intro: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "waveform.badge.mic")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(p.accent)
            Text("Калибровка распознавания")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(p.ink)
            Text("Прочитай вслух несколько заготовленных фраз. Мы сравним их с тем, что услышала модель, и предложим добавить в словарь слова, которые она путает именно на твоём голосе.")
                .font(.system(size: 14))
                .foregroundStyle(p.muted)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 40)
            Spacer()
            HStack(spacing: 12) {
                secondaryButton("Отмена", action: onClose)
                primaryButton("Начать") { session.begin(coordinator: coordinator) }
            }
            .padding(.bottom, 28)
        }
    }

    // MARK: - Запись

    private var recording: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Фраза \(session.progress.done + 1) из \(session.progress.total)")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(p.muted)
                Spacer()
                Button("Отмена", action: { session.cancel(); onClose() })
                    .buttonStyle(.plain)
                    .font(.system(size: 12.5))
                    .foregroundStyle(p.muted)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)

            Spacer()

            Text("«\(session.currentPhrase)»")
                .font(.system(size: 21, weight: .medium))
                .foregroundStyle(p.ink)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 40)

            Spacer()

            Text(session.isRecording ? "Идёт запись — прочитай фразу и нажми «Стоп»" : "Нажми «Записать» и прочитай фразу вслух")
                .font(.system(size: 13))
                .foregroundStyle(p.muted)
                .padding(.bottom, 16)

            recordButton
                .padding(.bottom, 14)

            if session.canFinishEarly {
                Button("Достаточно, показать результат", action: { session.finishEarly() })
                    .buttonStyle(.plain)
                    .font(.system(size: 12.5))
                    .foregroundStyle(p.accent)
                    .padding(.bottom, 22)
            } else {
                Spacer().frame(height: 40)
            }
        }
    }

    private var recordButton: some View {
        Button(action: { session.toggleRecord() }) {
            HStack(spacing: 9) {
                Image(systemName: session.isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 15))
                Text(session.isRecording ? "Стоп" : "Записать")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.vertical, 11)
            .padding(.horizontal, 26)
            .background(session.isRecording ? Color.red : p.accent)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Результаты

    private var results: some View {
        VStack(spacing: 0) {
            Text("Результат калибровки")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(p.ink)
                .padding(.top, 24)

            let found = session.result?.suggestions.count ?? 0
            Text(found == 0
                 ? "Модель распознала всё верно — добавлять нечего. Отличный голос!"
                 : "Нашли \(found) слов(а), которые модель путает. Добавить исправления в словарь?")
                .font(.system(size: 14))
                .foregroundStyle(p.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
                .padding(.top, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(session.result?.suggestions ?? [], id: \.pattern) { s in
                        row(icon: "arrow.right", left: s.pattern, right: s.replacement)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 16)
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: 12) {
                secondaryButton("Закрыть", action: onClose)
                if found > 0 {
                    primaryButton("Добавить в словарь") {
                        Task { await session.apply(); onClose() }
                    }
                }
            }
            .padding(.bottom, 24)
        }
    }

    private func row(icon: String, left: String?, right: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(p.muted2)
                .frame(width: 16)
            if let left {
                Text(left).font(.system(size: 14)).foregroundStyle(p.muted)
                Image(systemName: "arrow.right").font(.system(size: 11)).foregroundStyle(p.muted2)
            }
            Text(right).font(.system(size: 14, weight: .medium)).foregroundStyle(p.ink)
            Spacer()
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 12)
        .background(p.card)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    // MARK: - Кнопки

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.vertical, 9)
                .padding(.horizontal, 22)
                .background(p.accent)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(p.ink)
                .padding(.vertical, 9)
                .padding(.horizontal, 22)
                .background(p.selection)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
