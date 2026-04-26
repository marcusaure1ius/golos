import SwiftUI

struct ModelsPane: View {
    @StateObject private var manager = ModelManager()

    var body: some View {
        Form {
            Section {
                ModelCard(
                    name: "Качество",
                    meta: "GigaAM-v3 e2e_rnnt · ~340 МБ",
                    isActive: AppSettings.shared.modelMode == .quality,
                    isInstalled: manager.isInstalled(.gigaamRnnt)
                )
                ModelCard(
                    name: "Скорость",
                    meta: "GigaAM-v3 e2e_ctc · ~220 МБ",
                    isActive: AppSettings.shared.modelMode == .speed,
                    isInstalled: manager.isInstalled(.gigaamCtc)
                )
            }
            Section {
                Text("Все модели работают полностью локально.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Модели")
    }
}

struct ModelCard: View {
    let name: String
    let meta: String
    let isActive: Bool
    let isInstalled: Bool

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
                Button("Удалить") {}
            } else {
                Button("Загрузить") {}
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(.vertical, 4)
    }

    private func tag(_ s: String, color: Color) -> some View {
        Text(s)
            .font(.caption2).fontWeight(.semibold)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
            .foregroundColor(color)
    }
}
