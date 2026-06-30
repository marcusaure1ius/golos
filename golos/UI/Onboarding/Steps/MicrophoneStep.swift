import SwiftUI
import AVFoundation

struct MicrophoneStep: View {
    @Environment(\.palette) var p
    @EnvironmentObject private var coordinator: AppCoordinator
    @State private var status: AVAuthorizationStatus = Permissions.microphoneStatus()
    @State private var levels: [Float] = []
    @State private var monitoring = false
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var granted: Bool { status == .authorized }

    var body: some View {
        StepLayout(
            icon: "mic",
            title: "Дай услышать тебя",
            subtitle: granted
                ? "Отлично — я тебя слышу. Скажи что-нибудь, и волна отзовётся."
                : "Golos слушает микрофон и расшифровывает речь прямо на твоём Mac — звук никуда не уходит."
        ) {
            VStack(alignment: .leading, spacing: 12) {
                if granted {
                    Label("Микрофон подключён", systemImage: "checkmark.circle")
                        .font(.system(size: 13.5))
                        .foregroundStyle(p.ink)
                    if monitoring {
                        WaveformView(levels: levels, live: true, maxHeight: 56)
                    }
                } else {
                    ctaView
                    if status == .notDetermined {
                        Text("macOS покажет системный диалог")
                            .font(.system(size: 11.5))
                            .foregroundStyle(p.muted2)
                    }
                }
            }
            .padding(.top, 6)
        }
        .onAppear {
            if status == .notDetermined {
                Permissions.requestMicrophone { _ in status = Permissions.microphoneStatus() }
            }
            startMonitoringIfGranted()
        }
        .onDisappear { stopMonitoring() }
        .onReceive(timer) { _ in
            status = Permissions.microphoneStatus()
            if granted { startMonitoringIfGranted() } else { stopMonitoring() }
        }
        .onReceive(coordinator.audio.$level) { lvl in
            guard monitoring else { return }
            levels.append(lvl)
            if levels.count > 32 { levels.removeFirst(levels.count - 32) }
        }
    }

    @ViewBuilder private var ctaView: some View {
        switch status {
        case .notDetermined:
            Button("Разрешить микрофон") {
                Permissions.requestMicrophone { _ in status = Permissions.microphoneStatus() }
            }.buttonStyle(PrimaryButton())
        case .denied, .restricted:
            Button("Открыть System Settings") {
                let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!
                NSWorkspace.shared.open(url)
            }.buttonStyle(PrimaryButton())
        case .authorized:
            EmptyView()
        @unknown default:
            EmptyView()
        }
    }

    private func startMonitoringIfGranted() {
        guard granted, !monitoring else { return }
        do { try coordinator.audio.start(); monitoring = true }
        catch { Log.ui.warning("mic monitor start failed: \(error.localizedDescription, privacy: .public)") }
    }

    private func stopMonitoring() {
        guard monitoring else { return }
        coordinator.audio.stop()
        monitoring = false
    }
}
