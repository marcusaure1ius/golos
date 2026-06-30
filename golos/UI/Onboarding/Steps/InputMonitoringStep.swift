import SwiftUI

struct InputMonitoringStep: View {
    @State private var granted: Bool = Permissions.inputMonitoringGranted()
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        StepLayout(
            iconColors: [.indigo, .purple],
            icon: "keyboard",
            title: "Доступ к клавиатуре",
            subtitle: "Чтобы реагировать на твой хоткей в любом приложении."
        ) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 12) {
                    NumberedSteps(items: [
                        "System Settings → Privacy & Security → Input Monitoring",
                        "Включи Golos"
                    ])
                    HStack(spacing: 10) {
                        Button("Открыть System Settings") { Permissions.openInputMonitoringSettings() }
                            .buttonStyle(.borderedProminent)
                        PermStatusPill(granted: granted, pendingText: "Ожидаю включения…")
                    }
                }
                .padding(14)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))

                Text("Это разрешение нужно только для одной клавиши — Right Option. Golos не читает ничего из того, что ты печатаешь.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
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
