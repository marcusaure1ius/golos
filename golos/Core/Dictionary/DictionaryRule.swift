import Foundation

/// Одно правило пользовательского словаря: заменить ошибочно распознанный
/// фрагмент (`pattern`) на правильный (`replacement`).
///
/// Матчинг — по целым словам/фразам, без учёта регистра (см. `TranscriptCorrector`).
struct DictionaryRule: Codable, Identifiable, Equatable {
    let id: UUID
    var pattern: String
    var replacement: String
    var enabled: Bool

    init(id: UUID = UUID(), pattern: String, replacement: String, enabled: Bool = true) {
        self.id = id
        self.pattern = pattern
        self.replacement = replacement
        self.enabled = enabled
    }
}
