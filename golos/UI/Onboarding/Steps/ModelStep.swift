import SwiftUI

struct ModelStep: View {
    @ObservedObject var settings: AppSettings = .shared
    @ObservedObject var vm: OnboardingViewModel
    @StateObject private var manager = ModelManager()
    @State private var downloadingId: String?
    @State private var lastAttempted: ModelDescriptor?

    var body: some View {
        StepLayout(
            iconColors: [.orange, .yellow],
            icon: "shippingbox.fill",
            title: "Выбери модель",
            subtitle: "Можно поменять позже в настройках. Модель скачается локально."
        ) {
            VStack(spacing: 8) {
                row(.gigaamRnnt, name: "Качество", meta: "Лучше распознаёт сложные фразы", size: "~340 МБ", isSelected: settings.modelMode == .quality)
                row(.gigaamCtc, name: "Скорость", meta: "На 30–40% быстрее, чуть слабее по качеству", size: "~220 МБ", isSelected: settings.modelMode == .speed)

                if let p = manager.progress, downloadingId != nil {
                    VStack(spacing: 4) {
                        ProgressView(value: p.fraction)
                        HStack {
                            Text("Загружаю…")
                            Spacer()
                            Text("\(Int(p.fraction * 100))%")
                        }
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)
                }

                if let err = manager.error {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
                        Text(err).font(.system(size: 11)).foregroundStyle(.secondary)
                        Spacer()
                        Button("Повторить") { Task { await retry() } }
                    }
                    .padding(.top, 8)
                }
            }
        }
    }

    @ViewBuilder
    private func row(_ desc: ModelDescriptor, name: String, meta: String, size: String, isSelected: Bool) -> some View {
        ModelChoice(
            name: name, meta: meta, size: size,
            isSelected: isSelected,
            isInstalled: manager.isInstalled(desc),
            isDownloading: downloadingId == desc.id,
            onSelect: {
                if desc.id == "e2e_rnnt" { settings.modelMode = .quality } else { settings.modelMode = .speed }
            },
            onDownload: { Task { await download(desc) } }
        )
    }

    private func download(_ desc: ModelDescriptor) async {
        guard downloadingId == nil else { return }
        lastAttempted = desc
        downloadingId = desc.id
        defer { downloadingId = nil }
        do {
            try await manager.download(desc)
            vm.modelReady = manager.isInstalled(desc)
        } catch { /* error через manager.error */ }
    }

    private func retry() async {
        guard let desc = lastAttempted else {
            await download(settings.modelMode.descriptor)
            return
        }
        await download(desc)
    }
}

struct ModelChoice: View {
    let name: String
    let meta: String
    let size: String
    let isSelected: Bool
    let isInstalled: Bool
    let isDownloading: Bool
    let onSelect: () -> Void
    let onDownload: () -> Void

    var body: some View {
        HStack(spacing: 12) {
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
            }
            .buttonStyle(.plain)

            if !isInstalled {
                Button(isDownloading ? "Скачиваю…" : "Загрузить") { onDownload() }
                    .disabled(isDownloading)
            } else {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            }
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(isSelected ? Color.accentColor : .clear, lineWidth: 1.5))
    }
}
