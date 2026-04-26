import SwiftUI
import AVFoundation

struct MicrophoneStep: View {
    @State private var status: AVAuthorizationStatus = Permissions.microphoneStatus()

    var body: some View {
        StepLayout(
            iconColors: [.red, .orange],
            icon: "mic.fill",
            title: "Доступ к микрофону",
            subtitle: "Чтобы расшифровывать твою речь, мне нужно слышать вход с микрофона."
        ) {
            PermCard(
                iconColors: [.red, .orange],
                iconName: "mic.fill",
                title: "Микрофон",
                subtitle: "macOS покажет системный диалог."
            ) {
                PermStatusPill(granted: status == .authorized, pendingText: "Не разрешено")
            }
        }
        .onAppear {
            if status == .notDetermined {
                Permissions.requestMicrophone { _ in status = Permissions.microphoneStatus() }
            }
        }
    }
}
