import SwiftUI

struct HotkeysPane: View {
    @ObservedObject var settings: AppSettings = .shared

    var body: some View {
        Form {
            Section {
                LabeledContent("Push-to-talk:") {
                    HStack {
                        Text("⌥ Right · hold")
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 6))
                        Button("Изменить…") {}
                    }
                }
                LabeledContent("Toggle:") {
                    HStack {
                        Text("⌥ Right · ×2")
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 6))
                        Button("Изменить…") {}
                    }
                }
                Picker("Минимальное время удержания:", selection: $settings.holdMs) {
                    Text("150 мс").tag(150)
                    Text("200 мс").tag(200)
                    Text("300 мс").tag(300)
                }
                Picker("Окно double-tap:", selection: $settings.doubleTapMs) {
                    Text("200 мс").tag(200)
                    Text("300 мс").tag(300)
                    Text("500 мс").tag(500)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Хоткеи")
    }
}
