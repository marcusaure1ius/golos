import SwiftUI

struct PrivacyPane: View {
    @ObservedObject var settings: AppSettings = .shared

    var body: some View {
        Form {
            Section {
                Toggle("Сохранять историю транскриптов", isOn: $settings.historyEnabled)
                Picker("Хранить:", selection: $settings.historyRetentionDays) {
                    Text("30 дней").tag(30)
                    Text("90 дней").tag(90)
                    Text("Бессрочно").tag(0)
                }.disabled(!settings.historyEnabled)
                Toggle("Анонимная диагностика", isOn: $settings.diagnostics)
            }
            Section {
                Text("Аудио и транскрипты никогда не покидают этот Mac. Голосовая модель работает локально.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Приватность")
    }
}
