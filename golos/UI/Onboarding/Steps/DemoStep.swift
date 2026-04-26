import SwiftUI

struct DemoStep: View {
    @State private var text: String = ""

    var body: some View {
        StepLayout(
            iconColors: [.teal, .cyan],
            icon: "mic.fill",
            title: "Попробуй прямо сейчас",
            subtitle: "Удерживай правый ⌥ и продиктуй любую фразу."
        ) {
            VStack(spacing: 12) {
                ZStack(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("Здесь появится твой текст…")
                            .foregroundStyle(.secondary)
                            .padding(14)
                    }
                    TextEditor(text: $text)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                }
                .frame(minHeight: 100)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.secondary.opacity(0.3), lineWidth: 1))

                Text("Если всё работает — закрой это окно и продолжай в любом приложении.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
