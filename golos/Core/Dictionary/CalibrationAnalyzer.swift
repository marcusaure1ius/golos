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
            let heardLower = Set(heard.map { $0.lowercased() })

            // Слова эталона, которых нет в распознанном → bias.
            for word in expected where word.count >= minWordLength {
                let key = word.lowercased()
                if !heardLower.contains(key), !biasSeen.contains(key) {
                    biasSeen.insert(key)
                    biasTerms.append(word)
                }
            }

            // Позиционные подмены при равной длине → правила замены.
            if expected.count == heard.count {
                for (e, h) in zip(expected, heard) where e.count >= minWordLength {
                    if e.lowercased() != h.lowercased() && !h.isEmpty {
                        let key = h.lowercased()
                        if !ruleSeen.contains(key) {
                            ruleSeen.insert(key)
                            suggestions.append(CorrectionSuggestion(pattern: h, replacement: e))
                        }
                    }
                }
            }
        }

        // Правило замены само работает как bias (координатор биасит по «заменить на»),
        // поэтому слова, уже покрытые правилом, не дублируем отдельным bias-термином.
        let ruleReplacements = Set(suggestions.map { $0.replacement.lowercased() })
        let dedupedBias = biasTerms.filter { !ruleReplacements.contains($0.lowercased()) }

        return CalibrationResult(biasTerms: dedupedBias, suggestions: suggestions)
    }

    // MARK: - Внутреннее

    private static let trimSet = CharacterSet.punctuationCharacters.union(.symbols)

    private static func tokenize(_ s: String) -> [String] {
        s.split(whereSeparator: { $0 == " " || $0 == "\n" || $0 == "\t" })
            .map { $0.trimmingCharacters(in: trimSet) }
            .filter { !$0.isEmpty }
    }
}
