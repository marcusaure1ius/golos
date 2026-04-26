import SwiftUI

struct ModelStep: View {
    @ObservedObject var settings: AppSettings = .shared
    @StateObject private var manager = ModelManager()

    var body: some View {
        StepLayout(
            iconColors: [.orange, .yellow],
            icon: "shippingbox.fill",
            title: "Выбери модель",
            subtitle: "Можно поменять позже в настройках. Можно держать обе и переключаться."
        ) {
            VStack(spacing: 8) {
                ModelChoice(name: "Качество", meta: "Лучше распознаёт сложные фразы", size: "~340 МБ", isSelected: settings.modelMode == .quality) {
                    settings.modelMode = .quality
                }
                ModelChoice(name: "Скорость", meta: "На 30–40% быстрее, чуть слабее по качеству", size: "~220 МБ", isSelected: settings.modelMode == .speed) {
                    settings.modelMode = .speed
                }

                if let p = manager.progress {
                    VStack(spacing: 4) {
                        ProgressView(value: p.fraction)
                        HStack {
                            Text("Загружаю «\(settings.modelMode == .quality ? "Качество" : "Скорость")»…")
                            Spacer()
                            Text("\(Int(p.fraction * 100))%")
                        }
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)
                }
            }
        }
    }
}

struct ModelChoice: View {
    let name: String
    let meta: String
    let size: String
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: 1.5)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle().fill(Color.accentColor).frame(width: 22, height: 22)
                        Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundColor(.white)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(name).font(.system(size: 13, weight: .semibold))
                    Text(meta).font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                Text(size).font(.system(size: 11)).foregroundStyle(.secondary)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 5))
            }
            .padding(12)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(isSelected ? Color.accentColor : .clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }
}
