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
    @Environment(\.palette) var p

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Заголовок панели
                Text("Общее")
                    .font(.system(size: 26, weight: .semibold))
                    .tracking(-0.3)
                    .foregroundStyle(p.ink)
                    .padding(.bottom, 28)

                // Секция: Внешний вид
                GSectionHeader("Внешний вид")
                    .padding(.bottom, 10)

                GCard {
                    GSettingRow("Тема", showTopDivider: false) {
                        Picker("", selection: $settings.themeMode) {
                            ForEach(AppSettings.ThemeMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .fixedSize()
                    }
                }
                .padding(.bottom, 24)

                // Секция: Запуск
                GSectionHeader("Запуск")
                    .padding(.bottom, 10)

                GCard {
                    GSettingRow("Запускать при входе в систему", showTopDivider: false) {
                        VStack(alignment: .trailing, spacing: 4) {
                            Toggle("", isOn: $settings.autolaunch)
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .tint(p.accent)
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
                                    .foregroundStyle(p.danger)
                                    .multilineTextAlignment(.trailing)
                            }
                        }
                    }
                }
                .padding(.bottom, 24)

                // Секция: Поведение
                GSectionHeader("Поведение")
                    .padding(.bottom, 10)

                GCard {
                    GSettingRow("Уведомления", showTopDivider: false) {
                        Toggle("", isOn: $settings.notifications)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .tint(p.accent)
                    }
                    GSettingRow("Звук при старте и окончании") {
                        Toggle("", isOn: $settings.startSound)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .tint(p.accent)
                    }
                }
            }
            .padding(.horizontal, 56)
            .padding(.vertical, 38)
            .frame(maxWidth: 712) // 56+56 padding + 600 inner
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .onAppear {
            if #available(macOS 13.0, *) {
                settings.autolaunch = Autolaunch.isEnabled
            }
        }
    }
}
