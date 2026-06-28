import SwiftUI

struct PrivacyPane: View {
    @ObservedObject var settings: AppSettings = .shared
    @Environment(\.palette) var p

    private var retentionLabel: String {
        switch settings.historyRetentionDays {
        case 30: return "30 дней"
        case 90: return "90 дней"
        default: return "Бессрочно"
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Заголовок панели
                Text("Приватность")
                    .font(.system(size: 26, weight: .semibold))
                    .tracking(-0.3)
                    .foregroundStyle(p.ink)
                    .padding(.bottom, 28)

                // Секция: История
                GSectionHeader("История")
                    .padding(.bottom, 10)

                GCard {
                    GSettingRow("Сохранять историю транскриптов", showTopDivider: false) {
                        Toggle("", isOn: $settings.historyEnabled)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .tint(p.accent)
                    }
                    GSettingRow("Хранить записи") {
                        Menu {
                            Button("30 дней") { settings.historyRetentionDays = 30 }
                            Button("90 дней") { settings.historyRetentionDays = 90 }
                            Button("Бессрочно") { settings.historyRetentionDays = 0 }
                        } label: {
                            GSelectLabel(retentionLabel)
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                        .disabled(!settings.historyEnabled)
                    }
                }
                .padding(.bottom, 24)

                // Секция: Диагностика
                GSectionHeader("Диагностика")
                    .padding(.bottom, 10)

                GCard {
                    GSettingRow("Анонимная диагностика",
                                desc: "Помогает находить ошибки. Без текста и аудио.",
                                showTopDivider: false) {
                        Toggle("", isOn: $settings.diagnostics)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .tint(p.accent)
                    }
                }
                .padding(.bottom, 16)

                // Сноска
                Text("Аудио и транскрипты не покидают этот Mac.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(p.muted2)
                    .lineSpacing(3.75) // line-height 1.5
            }
            .padding(.horizontal, 56)
            .padding(.vertical, 38)
            .frame(maxWidth: 712)
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}
