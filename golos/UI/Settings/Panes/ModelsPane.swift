import SwiftUI

struct ModelsPane: View {
    @ObservedObject var settings: AppSettings = .shared
    @StateObject private var manager = ModelManager()
    @State private var downloadingId: String?
    @Environment(\.palette) var p

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Заголовок панели
                Text("Модели")
                    .font(.system(size: 26, weight: .semibold))
                    .tracking(-0.3)
                    .foregroundStyle(p.ink)
                    .padding(.bottom, 28)

                // Секция: Модель распознавания
                GSectionHeader("Модель распознавания",
                               desc: "Обе работают локально на этом Mac")
                    .padding(.bottom, 14)

                // fixedSize(vertical:true) + maxHeight:.infinity на каждой карточке
                // выравнивает высоту по самой высокой (той, где есть кнопка «Загрузить»).
                HStack(spacing: 12) {
                    radioCard(mode: .quality,
                              title: "Качество",
                              subtitle: "GigaAM-v3\n340 МБ",
                              desc: .gigaamRnnt)
                    radioCard(mode: .speed,
                              title: "Скорость",
                              subtitle: "GigaAM-v3\n220 МБ",
                              desc: .gigaamCtc)
                }
                .fixedSize(horizontal: false, vertical: true)

                // Прогресс загрузки
                if let prog = manager.progress, downloadingId != nil {
                    VStack(alignment: .leading, spacing: 4) {
                        ProgressView(value: prog.fraction)
                        Text("\(Int(prog.fraction * 100))% — \(formatBytes(prog.bytesDownloaded)) / \(formatBytes(prog.bytesTotal))")
                            .font(.caption)
                            .foregroundStyle(p.muted)
                    }
                    .padding(.top, 12)
                }

                // Ошибка
                if let err = manager.error {
                    Label(err, systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(p.danger)
                        .padding(.top, 8)
                }
            }
            .padding(.horizontal, 56)
            .padding(.vertical, 38)
            .frame(maxWidth: 712)
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    @ViewBuilder
    private func radioCard(mode: AppSettings.ModelMode,
                           title: String,
                           subtitle: String,
                           desc: ModelDescriptor) -> some View {
        let isInstalled = manager.isInstalled(desc)
        let isSelected = settings.modelMode == mode
        let isDownloading = downloadingId == desc.id

        GRadioCard(title: title, subtitle: subtitle, selected: isSelected) {
            if !isInstalled {
                Button(isDownloading ? "Скачиваю…" : "Загрузить") {
                    Task { await download(desc) }
                }
                .buttonStyle(GhostButton())
                .disabled(isDownloading)
                .padding(.top, 7) // итого 12pt от subtitle (spacing 5 + pad 7)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onTapGesture {
            if isInstalled {
                settings.modelMode = mode
            }
        }
    }

    private func download(_ desc: ModelDescriptor) async {
        guard downloadingId == nil else { return }
        downloadingId = desc.id
        defer { downloadingId = nil }
        try? await manager.download(desc)
    }

    private func formatBytes(_ b: Int64) -> String {
        let f = ByteCountFormatter()
        f.allowedUnits = [.useMB, .useGB]
        f.countStyle = .file
        return f.string(fromByteCount: b)
    }
}
