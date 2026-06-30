import SwiftUI

struct ModelStep: View {
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
            iconColors: [.orange, .yellow],
            icon: "shippingbox.fill",
            title: "Модель распознавания",
            subtitle: "Распознавание работает локально. Модель скачается один раз."
        ) {
            VStack(spacing: 8) {
                ModelRow(
                    name: model.displayName,
                    meta: "Локальное распознавание русской речи",
                    size: sizeText,
                    isInstalled: manager.isInstalled(model),
                    isDownloading: isDownloading,
                    onDownload: { Task { await download() } }
                )

                if let p = manager.progress, isDownloading {
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
                        Button("Повторить") { Task { await download() } }
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
    let name: String
    let meta: String
    let size: String
    let isInstalled: Bool
    let isDownloading: Bool
    let onDownload: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.system(size: 13, weight: .semibold))
                Text(meta).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            Text(size).font(.system(size: 11)).foregroundStyle(.secondary)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 5))

            if !isInstalled {
                Button(isDownloading ? "Скачиваю…" : "Скачать") { onDownload() }
                    .disabled(isDownloading)
            } else {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            }
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}
