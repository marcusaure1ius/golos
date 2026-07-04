import Foundation

/// Хранилище пользовательского словаря замен. Персистирует правила в JSON-файл.
///
/// Порядок правил значим: `TranscriptCorrector` применяет их сверху вниз.
actor DictionaryStore {

    // MARK: - Shared instance

    static let shared = DictionaryStore(fileURL: AppPaths.dictionaryFile)

    // MARK: - State

    private let fileURL: URL
    /// nil = ещё не загружали с диска (ленивая загрузка).
    private var _rules: [DictionaryRule]?

    private var rulesLoaded: [DictionaryRule] {
        if _rules == nil {
            _rules = Self.load(from: fileURL)
        }
        return _rules!
    }

    // MARK: - Init

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    // MARK: - Public API

    /// Все правила в порядке применения.
    func all() -> [DictionaryRule] {
        rulesLoaded
    }

    /// Добавляет правило в конец списка и сохраняет.
    func add(pattern: String, replacement: String) {
        if _rules == nil { _rules = Self.load(from: fileURL) }
        _rules!.append(DictionaryRule(pattern: pattern, replacement: replacement))
        save()
    }

    /// Заменяет правило с тем же id (pattern/replacement/enabled) и сохраняет.
    func update(_ rule: DictionaryRule) {
        if _rules == nil { _rules = Self.load(from: fileURL) }
        guard let idx = _rules!.firstIndex(where: { $0.id == rule.id }) else { return }
        _rules![idx] = rule
        save()
    }

    /// Удаляет правило по идентификатору и сохраняет.
    func delete(id: UUID) {
        if _rules == nil { _rules = Self.load(from: fileURL) }
        _rules!.removeAll { $0.id == id }
        save()
    }

    // MARK: - Persistence

    private func save() {
        guard let rules = _rules else { return }
        do {
            let data = try JSONEncoder().encode(rules)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            Log.coordinator.error("dictionary save failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func load(from url: URL) -> [DictionaryRule] {
        guard let data = try? Data(contentsOf: url),
              let rules = try? JSONDecoder().decode([DictionaryRule].self, from: data) else {
            return []
        }
        return rules
    }
}
