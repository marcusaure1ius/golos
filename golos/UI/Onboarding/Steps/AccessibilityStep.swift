import SwiftUI

struct AccessibilityStep: View {
    @State private var granted: Bool = Permissions.accessibilityGranted()
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        StepLayout(
            iconColors: [.blue, .indigo],
            icon: "person.fill",
            title: "Универсальный доступ",
            subtitle: "Чтобы я мог вставлять текст в приложения, в которые ты диктуешь."
        ) {
            VStack(alignment: .leading, spacing: 12) {
                NumberedSteps(items: [
                    "Открой System Settings → Privacy & Security → Accessibility",
                    "Найди golos и включи переключатель",
                    "Вернись сюда — статус обновится автоматически"
                ])
                HStack(spacing: 10) {
                    Button("Открыть System Settings") { Permissions.openAccessibilitySettings() }
                        .buttonStyle(.borderedProminent)
                    PermStatusPill(granted: granted, pendingText: "Ожидаю включения…")
                }
            }
            .padding(14)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
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
