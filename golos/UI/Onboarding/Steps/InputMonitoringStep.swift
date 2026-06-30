import SwiftUI

struct InputMonitoringStep: View {
    @Environment(\.palette) var p
    @EnvironmentObject private var coordinator: AppCoordinator
    @State private var granted: Bool = Permissions.inputMonitoringGranted()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        StepLayout(
            icon: "keyboard",
            title: "Дай поймать горячую клавишу",
            subtitle: "Чтобы реагировать на твой хоткей в любом приложении."
        ) {
            VStack(alignment: .leading, spacing: 12) {
                if granted {
                    Label("Доступ открыт", systemImage: "checkmark.circle")
                        .font(.system(size: 13.5))
                        .foregroundStyle(p.ink)
                } else {
                    NumberedSteps(items: [
                        "System Settings → Privacy & Security → Input Monitoring",
                        "Включи Golos"
                    ])
                    Button("Открыть System Settings") { Permissions.openInputMonitoringSettings() }
                        .buttonStyle(PrimaryButton())
                    Text("Это разрешение нужно только для одной клавиши — Right Option. Golos не читает ничего из того, что ты печатаешь.")
                        .font(.system(size: 12))
                        .foregroundStyle(p.muted)
                }
            }
            .padding(.top, 6)
        }
        .onAppear {
            // Регистрируем намерение получить Input Monitoring — это добавляет golos
            // в список System Settings, даже если ещё не выдан.
            _ = Permissions.requestInputMonitoring()
            if granted { coordinator.startHotkeysIfNeeded() }
        }
        .onReceive(timer) { _ in
            granted = Permissions.inputMonitoringGranted()
            // Доступ мог быть выдан только что — поднять хоткей-tap (на старте его
            // ещё не было, и сам он не пересоздаётся).
            if granted { coordinator.startHotkeysIfNeeded() }
        }
    }
}
