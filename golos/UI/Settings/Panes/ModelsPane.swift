import SwiftUI

struct ModelsPane: View {
    @StateObject private var manager = ModelManager()
    @State private var downloadingId: String?

    var body: some View {
        Form {
            Section {
                modelRow(.gigaamRnnt, name: "Качество", meta: "GigaAM-v3 e2e_rnnt · ~340 МБ", isActive: AppSettings.shared.modelMode == .quality)
                modelRow(.gigaamCtc, name: "Скорость", meta: "GigaAM-v3 e2e_ctc · ~220 МБ", isActive: AppSettings.shared.modelMode == .speed)
            }
            if let p = manager.progress, downloadingId != nil {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        ProgressView(value: p.fraction)
                        Text("\(Int(p.fraction * 100))% — \(formatBytes(p.bytesDownloaded)) / \(formatBytes(p.bytesTotal))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            if let err = manager.error {
                Section {
                    Label(err, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            }
            Section {
                Text("Все модели работают полностью локально.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Модели")
    }

    private func modelRow(_ desc: ModelDescriptor, name: String, meta: String, isActive: Bool) -> some View {
        ModelCard(
            name: name, meta: meta, isActive: isActive,
            isInstalled: manager.isInstalled(desc),
            isDownloading: downloadingId == desc.id,
            onDownload: { Task { await download(desc) } },
            onDelete: { delete(desc) }
        )
    }

    private func download(_ desc: ModelDescriptor) async {
        guard downloadingId == nil else { return }
        downloadingId = desc.id
        defer { downloadingId = nil }
        try? await manager.download(desc)
    }

    private func delete(_ desc: ModelDescriptor) {
        let dir = manager.modelDir(desc.id)
        do { try FileManager.default.removeItem(at: dir) }
        catch { manager.surfaceError(error.localizedDescription) }
    }

    private func formatBytes(_ b: Int64) -> String {
        let f = ByteCountFormatter(); f.allowedUnits = [.useMB, .useGB]; f.countStyle = .file
        return f.string(fromByteCount: b)
    }
}

struct ModelCard: View {
    let name: String
    let meta: String
    let isActive: Bool
    let isInstalled: Bool
    let isDownloading: Bool
    let onDownload: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(name).font(.headline)
                    if isActive { tag("Активна", color: .green) }
                    if isInstalled { tag("Загружена", color: .gray) }
                }
                Text(meta).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if isInstalled {
                Button("Удалить", role: .destructive) { onDelete() }
            } else {
                Button(isDownloading ? "Скачиваю…" : "Загрузить") { onDownload() }
                    .buttonStyle(.borderedProminent)
                    .disabled(isDownloading)
            }
        }
        .padding(.vertical, 4)
    }

    private func tag(_ s: String, color: Color) -> some View {
        Text(s).font(.caption2).fontWeight(.semibold)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
            .foregroundColor(color)
    }
}
