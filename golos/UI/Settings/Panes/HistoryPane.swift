import SwiftUI
import AppKit

// MARK: - Строка истории

private struct HistoryRow: View {
    let entry: TranscriptEntry
    let onCopy: () -> Void
    let onDelete: () -> Void

    @State private var hovering = false
    @Environment(\.palette) var p

    private static let timeFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            // Время
            Text(Self.timeFmt.string(from: entry.date))
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(p.muted2)
                .frame(width: 46, alignment: .leading)
                .padding(.top, 2)

            // Текст транскрипции
            Text(entry.text)
                .font(.system(size: 14.5))
                .foregroundStyle(p.ink)
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Кнопки действий — видны только при наведении
            HStack(spacing: 4) {
                HistoryIconButton(systemImage: "doc.on.doc", tooltip: "Копировать", palette: p) {
                    onCopy()
                }
                HistoryIconButton(systemImage: "trash", tooltip: "Удалить", palette: p) {
                    onDelete()
                }
            }
            .opacity(hovering ? 1 : 0)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 10)
        .background(hovering ? p.selection : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .onHover { hovering = $0 }
        .animation(.easeInOut(duration: 0.12), value: hovering)
    }
}

// MARK: - Иконка-кнопка

private struct HistoryIconButton: View {
    let systemImage: String
    let tooltip: String
    let palette: Palette
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .regular))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(hovering ? palette.ink : palette.muted)
                .frame(width: 28, height: 28)
                .background(hovering ? palette.selection : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(tooltip)
        .onHover { hovering = $0 }
    }
}

// MARK: - Панель «История»

struct HistoryPane: View {
    @ObservedObject var settings: AppSettings = .shared
    @Environment(\.palette) var p

    @State private var entries: [TranscriptEntry] = []
    @State private var query: String = ""

    // MARK: Вычисляемые

    private var filtered: [TranscriptEntry] {
        query.isEmpty
            ? entries
            : entries.filter { $0.text.localizedCaseInsensitiveContains(query) }
    }

    private var groups: [(label: String, items: [TranscriptEntry])] {
        HistoryStore.grouped(filtered, calendar: .current, now: Date())
    }

    // MARK: Загрузка / перезагрузка

    private func reload() async {
        entries = await HistoryStore.shared.all()
    }

    // MARK: Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Заголовок
                Text("История")
                    .font(.system(size: 26, weight: .semibold))
                    .tracking(-0.3)
                    .foregroundStyle(p.ink)

                // Поисковое поле
                searchField
                    .padding(.top, 18)

                // Контент
                if !settings.historyEnabled {
                    emptyState(
                        title: "История выключена",
                        subtitle: "Включи сохранение истории в разделе Приватность."
                    )
                } else if entries.isEmpty {
                    emptyState(
                        title: "Пока нет записей",
                        subtitle: "Подиктуй что-нибудь, и записи появятся здесь."
                    )
                } else if groups.isEmpty {
                    emptyState(
                        title: "Ничего не найдено",
                        subtitle: nil
                    )
                } else {
                    // Список, сгруппированный по дням
                    ForEach(groups, id: \.label) { group in
                        Text(group.label)
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(p.muted)
                            .padding(.horizontal, 2)
                            .padding(.top, 22)
                            .padding(.bottom, 6)

                        ForEach(group.items) { entry in
                            HistoryRow(
                                entry: entry,
                                onCopy: { copyEntry(entry) },
                                onDelete: { deleteEntry(entry) }
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 56)
            .padding(.vertical, 38)
            .frame(maxWidth: 712)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .task { await reload() }
    }

    // MARK: Поле поиска

    private var searchField: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13.5, weight: .regular))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(p.muted)

            TextField("Поиск по тексту…", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .foregroundStyle(p.ink)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(p.card)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(p.fieldBorder, lineWidth: 1)
        )
    }

    // MARK: Пустое состояние

    @ViewBuilder
    private func emptyState(title: String, subtitle: String?) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(p.ink)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 13.5))
                    .foregroundStyle(p.muted)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: Действия

    private func copyEntry(_ entry: TranscriptEntry) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(entry.text, forType: .string)
    }

    private func deleteEntry(_ entry: TranscriptEntry) {
        Task {
            await HistoryStore.shared.delete(id: entry.id)
            await reload()
        }
    }
}
