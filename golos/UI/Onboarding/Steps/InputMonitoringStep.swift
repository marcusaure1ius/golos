import SwiftUI

struct InputMonitoringStep: View {
    @State private var granted: Bool = Permissions.inputMonitoringGranted()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        StepLayout(
            iconColors: granted ? [.green, .mint] : [.indigo, .purple],
            icon: "keyboard",
            title: "Дай поймать горячую клавишу",
            subtitle: "Чтобы реагировать на твой хоткей в любом приложении."
        ) {
            PermissionScene(granted: granted, iconColors: granted ? [.green, .mint] : [.indigo, .purple], icon: "keyboard")
        } content: {
            VStack(alignment: .leading, spacing: 12) {
                if granted {
                    Label("Доступ открыт", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 13, weight: .medium)).foregroundStyle(.green)
                } else {
                    NumberedSteps(items: [
                        "System Settings → Privacy & Security → Input Monitoring",
                        "Включи Golos"
                    ])
                    Button("Открыть System Settings") { Permissions.openInputMonitoringSettings() }
                        .buttonStyle(.borderedProminent)
                    Text("Это разрешение нужно только для одной клавиши — Right Option. Golos не читает ничего из того, что ты печатаешь.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 6)
        }
        .onAppear {
            // Регистрируем намерение получить Input Monitoring — это добавляет golos
            // в список System Settings, даже если ещё не выдан.
            _ = Permissions.requestInputMonitoring()
        }
        .onReceive(timer) { _ in
            granted = Permissions.inputMonitoringGranted()
        }
    }
}
