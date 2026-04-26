import SwiftUI

struct GeneralPane: View {
    @ObservedObject var settings: AppSettings = .shared

    var body: some View {
        Form {
            Section {
                Toggle("Запускать при входе в систему", isOn: $settings.autolaunch)
                Toggle("Показывать иконку в menu bar", isOn: $settings.menuBarIcon)
                Toggle("Уведомления", isOn: $settings.notifications)
                Toggle("Звук при старте/окончании", isOn: $settings.startSound)
            }
            Section {
                Text("Все транскрипции выполняются локально. Аудио и текст никуда не отправляются.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Общее")
    }
}
