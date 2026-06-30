import SwiftUI

struct HelloStep: View {
    var body: some View {
        VStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 24)
                .fill(LinearGradient(colors: [.indigo, .purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 110, height: 110)
                .overlay(Image(systemName: "waveform").font(.system(size: 60, weight: .bold)).foregroundColor(.white))
                .shadow(color: .purple.opacity(0.45), radius: 24, y: 24)

            Text("Добро пожаловать в Golos").font(.system(size: 32, weight: .bold))
            Text("Я помогу тебе диктовать в любое приложение macOS. Запись локальная — голос и текст никуда не уходят. Давай настроимся за пару минут.")
                .font(.system(size: 14))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 420)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
