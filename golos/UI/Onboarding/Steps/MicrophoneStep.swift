import SwiftUI
import AVFoundation

struct MicrophoneStep: View {
    @State private var status: AVAuthorizationStatus = Permissions.microphoneStatus()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        StepLayout(
            iconColors: [.red, .orange],
            icon: "mic.fill",
            title: "Доступ к микрофону",
            subtitle: subtitleText
        ) {
            PermCard(
                iconColors: [.red, .orange],
                iconName: "mic.fill",
                title: "Микрофон",
                subtitle: cardSubtitle
            ) {
                PermStatusPill(granted: status == .authorized, pendingText: pendingText)
            }

            ctaView
                .padding(.top, 8)

            if status == .denied || status == .restricted {
                Text(deniedExplanation)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
        }
        .onAppear {
            if status == .notDetermined {
                Permissions.requestMicrophone { _ in status = Permissions.microphoneStatus() }
            }
        }
        .onReceive(timer) { _ in
            status = Permissions.microphoneStatus()
        }
    }

    private var subtitleText: String {
        switch status {
        case .authorized:
            return "Доступ к микрофону разрешён. Всё готово."
        case .denied, .restricted:
            return "Доступ к микрофону запрещён. Нужно открыть Системные настройки."
        default:
            return "Чтобы расшифровывать твою речь, мне нужно слышать вход с микрофона."
        }
    }

    private var cardSubtitle: String {
        switch status {
        case .authorized:   return "Разрешено."
        case .denied:       return "Запрещено пользователем."
        case .restricted:   return "Ограничено политикой."
        default:            return "macOS покажет системный диалог."
        }
    }

    private var pendingText: String {
        switch status {
        case .denied:      return "Запрещено"
        case .restricted:  return "Ограничено"
        default:           return "Не разрешено"
        }
    }

    private var deniedExplanation: String {
        if status == .restricted {
            return "Доступ к микрофону ограничен политикой устройства. Обратитесь к администратору."
        }
        return "Ты ранее запретил доступ к микрофону. Открой Системные настройки и разреши доступ для Golos."
    }

    @ViewBuilder
    private var ctaView: some View {
        switch status {
        case .notDetermined:
            Button("Запросить разрешение") {
                Permissions.requestMicrophone { _ in status = Permissions.microphoneStatus() }
            }
            .buttonStyle(.borderedProminent)
        case .denied, .restricted:
            Button("Открыть System Settings") {
                let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!
                NSWorkspace.shared.open(url)
            }
            .buttonStyle(.borderedProminent)
        case .authorized:
            EmptyView()
        @unknown default:
            EmptyView()
        }
    }
}
