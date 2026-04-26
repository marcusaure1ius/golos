import SwiftUI

struct AboutPane: View {
    var body: some View {
        VStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 22)
                .fill(LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 96, height: 96)
                .overlay(Image(systemName: "waveform").font(.system(size: 48, weight: .bold)).foregroundColor(.white))
                .shadow(color: .purple.opacity(0.45), radius: 18, y: 12)
            Text("golos").font(.title).bold()
            Text("Версия \(Bundle.main.shortVersion)").font(.caption).foregroundStyle(.secondary)
            Text("Локальная голосовая диктовка для macOS\nна основе GigaAM-v3")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            HStack(spacing: 14) {
                Link("GitHub", destination: URL(string: "https://github.com/")!)
                Link("Документация", destination: URL(string: "https://github.com/")!)
                Link("Сообщить об ошибке", destination: URL(string: "https://github.com/")!)
            }
            .font(.caption)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("О приложении")
    }
}

extension Bundle {
    var shortVersion: String { infoDictionary?["CFBundleShortVersionString"] as? String ?? "?" }
}
