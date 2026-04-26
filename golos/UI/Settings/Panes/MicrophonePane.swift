import SwiftUI

struct MicrophonePane: View {
    @ObservedObject var settings: AppSettings = .shared
    @EnvironmentObject var coordinator: AppCoordinator
    @State private var devices: [(uid: String, name: String)] = []

    var body: some View {
        Form {
            Section {
                Picker("Устройство:", selection: $settings.deviceUid) {
                    Text("По умолчанию").tag("")
                    ForEach(devices, id: \.uid) { device in
                        Text(device.name).tag(device.uid)
                    }
                }
                .onChange(of: settings.deviceUid) { newUid in
                    coordinator.audio.applySettings(
                        deviceUid: newUid,
                        voiceProcessingEnabled: settings.noiseReduction
                    )
                }

                Toggle("Шумоподавление (macOS Voice Isolation)", isOn: $settings.noiseReduction)
                    .onChange(of: settings.noiseReduction) { newValue in
                        coordinator.audio.applySettings(
                            deviceUid: settings.deviceUid,
                            voiceProcessingEnabled: newValue
                        )
                    }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Микрофон")
        .onAppear {
            devices = AudioDevices.list()
        }
    }
}
