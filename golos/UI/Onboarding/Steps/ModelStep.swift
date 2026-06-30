import SwiftUI

struct ModelStep: View {
    @Environment(\.palette) var p
    @ObservedObject var vm: OnboardingViewModel
    @EnvironmentObject private var coordinator: AppCoordinator
    @StateObject private var manager = ModelManager()
    @State private var isDownloading = false

    private let model = ModelDescriptor.gigaam

    private var sizeText: String {
        let total = model.files.compactMap(\.sizeBytes).reduce(0, +)
        guard total > 0 else { return "" }
        return "~\(Int((Double(total) / 1_000_000).rounded())) МБ"
    }

    var body: some View {
        StepLayout(
            icon: "shippingbox",
            title: "Модель распознавания",
            subtitle: "Распознавание работает локально. Модель скачается один раз."
        ) {
            VStack(alignment: .leading, spacing: 8) {
                ModelRow(
                    name: model.displayName,
                    meta: "Локальное распознавание русской речи",
                    size: sizeText,
                    isInstalled: manager.isInstalled(model),
                    isDownloading: isDownloading,
                    onDownload: { Task { await download() } }
                )

                if let prog = manager.progress, isDownloading {
                    VStack(alignment: .leading, spacing: 4) {
                        ProgressView(value: prog.fraction)
                            .tint(p.ink)
                        HStack {
                            Text("Загружаю…")
                            Spacer()
                            Text("\(Int(prog.fraction * 100))%")
                        }
                        .font(.system(size: 11))
                        .foregroundStyle(p.muted)
                    }
                    .padding(.top, 8)
                }

                if let err = manager.error {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(p.muted)
                        Text(err).font(.system(size: 11)).foregroundStyle(p.muted)
                        Spacer()
                        Button("Повторить") { Task { await download() } }
                            .buttonStyle(GhostButton())
                    }
                    .padding(.top, 8)
                }
            }
        }
        .onAppear { vm.modelReady = manager.isInstalled(model) }
    }

    private func download() async {
        guard !isDownloading else { return }
        isDownloading = true
        defer { isDownloading = false }
        do {
            try await manager.download(model)
            vm.modelReady = manager.isInstalled(model)
            await coordinator.warmupModelIfAvailable()
        } catch { /* ошибка показывается через manager.error */ }
    }
}

struct ModelRow: View {
    @Environment(\.palette) var p
    let name: String
    let meta: String
    let size: String
    let isInstalled: Bool
    let isDownloading: Bool
    let onDownload: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.system(size: 13, weight: .semibold)).foregroundStyle(p.ink)
                Text(meta).font(.system(size: 11)).foregroundStyle(p.muted)
            }
            Spacer()
            if !size.isEmpty {
                Text(size)
                    .font(.system(size: 11))
                    .foregroundStyle(p.muted)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(p.selection, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
            }

            if !isInstalled {
                Button(isDownloading ? "Скачиваю…" : "Скачать") { onDownload() }
                    .buttonStyle(PrimaryButton())
                    .disabled(isDownloading)
            } else {
                Image(systemName: "checkmark.circle").foregroundStyle(p.ink)
            }
        }
        .padding(12)
        .background(p.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(p.border, lineWidth: 1)
        )
    }
}
