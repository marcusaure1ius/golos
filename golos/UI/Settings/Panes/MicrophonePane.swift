import SwiftUI

struct MicrophonePane: View {
    @ObservedObject var settings: AppSettings = .shared
    @EnvironmentObject var coordinator: AppCoordinator
    @Environment(\.palette) var p
    @State private var devices: [(uid: String, name: String)] = []

    private var currentDeviceName: String {
        guard !settings.deviceUid.isEmpty else { return "По умолчанию" }
        return devices.first(where: { $0.uid == settings.deviceUid })?.name ?? "По умолчанию"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Заголовок панели
                Text("Микрофон")
                    .font(.system(size: 26, weight: .semibold))
                    .tracking(-0.3)
                    .foregroundStyle(p.ink)
                    .padding(.bottom, 28)

                GCard {
                    GSettingRow("Устройство ввода", showTopDivider: false) {
                        Menu {
                            Button("По умолчанию") { settings.deviceUid = "" }
                            ForEach(devices, id: \.uid) { device in
                                Button(device.name) { settings.deviceUid = device.uid }
                            }
                        } label: {
                            GSelectLabel(currentDeviceName)
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                    }
                    .onChange(of: settings.deviceUid) { newUid in
                        coordinator.audio.applySettings(
                            deviceUid: newUid,
                            voiceProcessingEnabled: settings.noiseReduction
                        )
                    }

                    GSettingRow("Шумоподавление", desc: "Убирает фоновый шум") {
                        Toggle("", isOn: $settings.noiseReduction)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .tint(p.accent)
                            .onChange(of: settings.noiseReduction) { newValue in
                                coordinator.audio.applySettings(
                                    deviceUid: settings.deviceUid,
                                    voiceProcessingEnabled: newValue
                                )
                            }
                    }
                }
            }
            .padding(.horizontal, 56)
            .padding(.vertical, 38)
            .frame(maxWidth: 712)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .onAppear {
            devices = AudioDevices.list()
        }
    }
}
