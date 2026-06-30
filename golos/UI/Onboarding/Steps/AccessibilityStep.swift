import SwiftUI

struct AccessibilityStep: View {
    @State private var granted: Bool = Permissions.accessibilityGranted()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        StepLayout(
            iconColors: granted ? [.green, .mint] : [.blue, .indigo],
            icon: "person.fill",
            title: "Разреши вставлять текст",
            subtitle: "Чтобы я мог вставлять текст в приложения, в которые ты диктуешь."
        ) {
            PermissionScene(granted: granted, iconColors: granted ? [.green, .mint] : [.blue, .indigo], icon: "accessibility")
        } content: {
            VStack(alignment: .leading, spacing: 12) {
                if granted {
                    Label("Доступ открыт", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 13, weight: .medium)).foregroundStyle(.green)
                } else {
                    NumberedSteps(items: [
                        "System Settings → Privacy & Security → Accessibility",
                        "Найди Golos и включи переключатель",
                        "Вернись сюда — статус обновится автоматически"
                    ])
                    Button("Открыть System Settings") { Permissions.openAccessibilitySettings() }
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding(.top, 6)
        }
        .onAppear {
            // Триггерим системный prompt — это также добавляет golos в список Accessibility,
            // даже если ещё не выдан (без prompt'а — нет записи в Settings).
            _ = Permissions.requestAccessibility()
        }
        .onReceive(timer) { _ in
            granted = Permissions.accessibilityGranted()
        }
    }
}

struct NumberedSteps: View {
    let items: [String]
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(items.enumerated()), id: \.offset) { idx, text in
                HStack(alignment: .top, spacing: 10) {
                    ZStack {
                        Circle().fill(Color.accentColor.opacity(0.12))
                        Text("\(idx + 1)").font(.system(size: 11, weight: .semibold)).foregroundColor(.accentColor)
                    }
                    .frame(width: 20, height: 20)
                    Text(text).font(.system(size: 13))
                }
            }
        }
    }
}
