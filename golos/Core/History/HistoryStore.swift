import Foundation

/// Хранилище истории транскрипций. Персистирует список в JSON-файл.
actor HistoryStore {

    // MARK: - Shared instance

    static let shared = HistoryStore(fileURL: AppPaths.historyFile)

    // MARK: - State

    private let fileURL: URL
    /// nil = ещё не загружали с диска (ленивая загрузка).
    private var _entries: [TranscriptEntry]?

    private var entries: [TranscriptEntry] {
        if _entries == nil {
            _entries = Self.load(from: fileURL)
        }
        return _entries!
    }

    // MARK: - Init

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    // MARK: - Public API

    /// Возвращает все записи (новые — первыми).
    func all() -> [TranscriptEntry] {
        entries
    }

    /// Добавляет новую запись в начало списка и сохраняет на диск.
    func add(text: String, date: Date) {
        let entry = TranscriptEntry(id: UUID(), text: text, date: date)
        if _entries == nil {
            _entries = Self.load(from: fileURL)
        }
        _entries!.insert(entry, at: 0)
        save()
    }

    /// Удаляет запись по идентификатору и сохраняет.
    func delete(id: UUID) {
        if _entries == nil { _entries = Self.load(from: fileURL) }
        _entries!.removeAll { $0.id == id }
        save()
    }

    /// Удаляет записи старше `retentionDays` дней. 0 = не удалять ничего.
    func prune(retentionDays: Int, now: Date) {
        guard retentionDays > 0 else { return }
        if _entries == nil { _entries = Self.load(from: fileURL) }
        let cutoff = now.addingTimeInterval(Double(-retentionDays) * 86400)
        _entries!.removeAll { $0.date < cutoff }
        save()
    }

    /// Поиск по подстроке без учёта регистра. Пустой запрос — все записи.
    func search(_ query: String) -> [TranscriptEntry] {
        guard !query.isEmpty else { return entries }
        return entries.filter { $0.text.localizedCaseInsensitiveContains(query) }
    }

    // MARK: - Grouping (чистая функция, не изолирована актором)

    /// Группирует записи по дням: «Сегодня», «Вчера», иначе — форматированная дата.
    /// Внутри каждой группы записи отсортированы по убыванию даты (новые первыми).
    nonisolated static func grouped(
        _ entries: [TranscriptEntry],
        calendar: Calendar,
        now: Date
    ) -> [(label: String, items: [TranscriptEntry])] {
        // Сортируем по убыванию даты
        let sorted = entries.sorted { $0.date > $1.date }

        // Группируем по календарному дню
        var orderKeys: [String] = []
        var groups: [String: [TranscriptEntry]] = [:]

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM yyyy"
        formatter.calendar = calendar

        for entry in sorted {
            let label: String
            if calendar.isDateInToday(entry.date) {
                label = "Сегодня"
            } else if calendar.isDateInYesterday(entry.date) {
                label = "Вчера"
            } else {
                label = formatter.string(from: entry.date)
            }

            if groups[label] == nil {
                orderKeys.append(label)
                groups[label] = []
            }
            groups[label]!.append(entry)
        }

        return orderKeys.map { key in (label: key, items: groups[key]!) }
    }

    // MARK: - Persistence

    private func save() {
        guard let entries = _entries else { return }
        do {
            let data = try JSONEncoder().encode(entries)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // Сбой сохранения — логируем и продолжаем (данные в памяти).
            Log.coordinator.error("history save failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func load(from url: URL) -> [TranscriptEntry] {
        guard let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([TranscriptEntry].self, from: data) else {
            return []
        }
        return entries
    }
}
