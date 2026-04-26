import SwiftUI
import ServiceManagement

@MainActor
final class GeneralPaneViewModel: ObservableObject {
    @Published var autolaunchError: String?

    @available(macOS 13.0, *)
    func setAutolaunch(_ enabled: Bool) {
        do {
            try Autolaunch.setEnabled(enabled)
            autolaunchError = nil
        } catch {
            autolaunchError = error.localizedDescription
        }
    }
}

struct GeneralPane: View {
    @ObservedObject var settings: AppSettings = .shared
    @StateObject private var vm = GeneralPaneViewModel()

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Запускать при входе в систему", isOn: $settings.autolaunch)
                        .onChange(of: settings.autolaunch) { newValue in
                            if #available(macOS 13.0, *) {
                                let previous = !newValue
                                vm.setAutolaunch(newValue)
                                if vm.autolaunchError != nil {
                                    settings.autolaunch = previous
                                }
                            }
                        }
                    if let err = vm.autolaunchError {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
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
        .onAppear {
            if #available(macOS 13.0, *) {
                settings.autolaunch = Autolaunch.isEnabled
            }
        }
    }
}
