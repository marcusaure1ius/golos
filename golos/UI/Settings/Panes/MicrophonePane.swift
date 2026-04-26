import SwiftUI

struct MicrophonePane: View {
    @ObservedObject var settings: AppSettings = .shared
    @State private var devices: [String] = ["По умолчанию"]

    var body: some View {
        Form {
            Section {
                Picker("Устройство:", selection: $settings.deviceUid) {
                    Text("По умолчанию").tag("")
                    ForEach(devices, id: \.self) { Text($0).tag($0) }
                }
                Toggle("Шумоподавление (macOS Voice Isolation)", isOn: $settings.noiseReduction)
                Button("Записать 3 секунды") {}
                    .controlSize(.regular)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Микрофон")
    }
}
