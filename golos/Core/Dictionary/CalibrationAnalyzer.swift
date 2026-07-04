import Foundation

/// Пара «эталон ↔ что услышала модель» из калибровки.
struct CalibrationPair: Equatable {
    let expected: String
    let heard: String
}

/// Предложенное правило замены (кривое написание → правильное).
struct CorrectionSuggestion: Equatable {
    let pattern: String
    let replacement: String
}

/// Результат анализа калибровки.
struct CalibrationResult: Equatable {
    /// Слова, которые модель распознала неверно → в bias-список.
    let biasTerms: [String]
    /// Явные исправления (одинаковая длина фраз, одно слово подменено) → в словарь.
    let suggestions: [CorrectionSuggestion]
}

/// Достаёт из пар «эталон ↔ распознанное» проблемные слова и явные исправления.
///
/// Мы знаем правильный текст фраз, поэтому расхождения — это точный сигнал об
/// ошибках именно этого голоса. Слова эталона, которых нет в распознанном, идут в
/// bias-список; позиционные подмены (при равной длине) — в правила замены.
/// Сравнение слов без учёта регистра; короткие слова (≤2 символов) игнорируем как шум.
enum CalibrationAnalyzer {

    private static let minWordLength = 3

    static func analyze(_ pairs: [CalibrationPair]) -> CalibrationResult {
        var biasSeen = Set<String>()
        var biasTerms: [String] = []
        var ruleSeen = Set<String>()
        var suggestions: [CorrectionSuggestion] = []

        for pair in pairs {
            let expected = tokenize(pair.expected)
            let heard = tokenize(pair.heard)

            if expected.count == heard.count {
                // Равная длина → позиционные подмены → правила замены.
                for (e, h) in zip(expected, heard) where e.count >= minWordLength {
                    guard !h.isEmpty, e.lowercased() != h.lowercased() else { continue }
                    guard isRealError(expected: e, heard: h) else { continue }
                    let key = h.lowercased()
                    if !ruleSeen.contains(key) {
                        ruleSeen.insert(key)
                        suggestions.append(CorrectionSuggestion(pattern: h, replacement: e))
                    }
                }
            } else {
                // Разная длина → слова эталона, которых нет в распознанном → bias.
                let heardLower = Set(heard.map { $0.lowercased() })
                for word in expected where word.count >= minWordLength {
                    let key = word.lowercased()
                    guard !heardLower.contains(key), !biasSeen.contains(key) else { continue }
                    guard !isNumeric(word) else { continue }               // числа не биасим
                    guard !heard.contains(where: { sameWordFamily(word, $0) }) else { continue } // словоформа уже есть
                    biasSeen.insert(key)
                    biasTerms.append(word)
                }
            }
        }

        // Правило само биасит по «заменить на» → не дублируем словом в bias.
        let ruleReplacements = Set(suggestions.map { $0.replacement.lowercased() })
        let dedupedBias = biasTerms.filter { !ruleReplacements.contains($0.lowercased()) }

        return CalibrationResult(biasTerms: dedupedBias, suggestions: suggestions)
    }

    // MARK: - Фильтры

    /// Настоящая ли это ошибка (а не словоформа/число). Отсекает: цифры↔слово
    /// (напр. «20»↔«двадцать») и однокоренные словоформы (напр. «приложений»↔
    /// «приложения») — их «исправлять» бессмысленно.
    private static func isRealError(expected: String, heard: String) -> Bool {
        if isNumeric(expected) || isNumeric(heard) { return false }
        if sameWordFamily(expected, heard) { return false }
        return true
    }

    private static func isNumeric(_ s: String) -> Bool {
        !s.isEmpty && s.allSatisfy { $0.isNumber }
    }

    /// Отличаются ли слова только окончанием при длинном общем корне (словоформы).
    private static func sameWordFamily(_ a: String, _ b: String) -> Bool {
        let al = Array(a.lowercased()), bl = Array(b.lowercased())
        var cp = 0
        while cp < al.count && cp < bl.count && al[cp] == bl[cp] { cp += 1 }
        let maxLen = max(al.count, bl.count)
        return cp >= 4 && cp >= maxLen - 3
    }

    // MARK: - Внутреннее

    private static let trimSet = CharacterSet.punctuationCharacters.union(.symbols)

    private static func tokenize(_ s: String) -> [String] {
        s.split(whereSeparator: { $0 == " " || $0 == "\n" || $0 == "\t" })
            .map { $0.trimmingCharacters(in: trimSet) }
            .filter { !$0.isEmpty }
    }
}
