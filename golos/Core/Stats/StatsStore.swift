import Foundation

/// Персистентная статистика использования: по-дневные бакеты (диктовки, слова).
/// Не зависит от капа истории — тоталы точны за всё время.
actor StatsStore {

    static let shared = StatsStore(fileURL: AppPaths.statsFile)

    /// Формат файла: флаг одноразового сидинга + бакеты.
    private struct Persisted: Codable {
        var seededFromHistory: Bool
        var buckets: [DayBucket]
    }

    private let fileURL: URL
    /// nil = ещё не загружали с диска (ленивая загрузка).
    private var _state: Persisted?

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    private func loadIfNeeded() {
        if _state == nil { _state = Self.load(from: fileURL) }
    }

    /// Все бакеты (по возрастанию даты).
    func snapshot() -> [DayBucket] {
        loadIfNeeded()
        return _state!.buckets
    }

    /// Учитывает одну диктовку в бакете дня `startOfDay(date)`.
    func record(wordCount: Int, date: Date) {
        loadIfNeeded()
        let day = Calendar.current.startOfDay(for: date)
        if let idx = _state!.buckets.firstIndex(where: { $0.day == day }) {
            _state!.buckets[idx].dictations += 1
            _state!.buckets[idx].words += wordCount
        } else {
            _state!.buckets.append(DayBucket(day: day, dictations: 1, words: wordCount))
            _state!.buckets.sort { $0.day < $1.day }
        }
        save()
    }

    /// Одноразовый бэкфилл из истории при первом запуске. Если записи уже есть —
    /// только выставляет флаг (не сидит, чтобы не задвоить). Идемпотентно.
    func seedIfNeeded(from entries: [TranscriptEntry]) {
        loadIfNeeded()
        guard !_state!.seededFromHistory else { return }
        if _state!.buckets.isEmpty {
            _state!.buckets = StatsAggregator.buckets(from: entries, calendar: .current)
        }
        _state!.seededFromHistory = true
        save()
    }

    // MARK: - Persistence

    private func save() {
        guard let state = _state else { return }
        do {
            let data = try JSONEncoder().encode(state)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            Log.coordinator.error("stats save failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func load(from url: URL) -> Persisted {
        guard let data = try? Data(contentsOf: url),
              let state = try? JSONDecoder().decode(Persisted.self, from: data) else {
            return Persisted(seededFromHistory: false, buckets: [])
        }
        return state
    }
}
