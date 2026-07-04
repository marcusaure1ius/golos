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

/// Результат анализа калибровки — только правила замены (левое+правое), чтобы не
/// плодить непонятные «пустые» записи. Правило само работает и как bias.
struct CalibrationResult: Equatable {
    let suggestions: [CorrectionSuggestion]
}

/// Достаёт из пар «эталон ↔ распознанное» правила замины для слов, которые модель
/// исказила именно на этом голосе.
///
/// Выравнивает последовательности слов (Нидлман-Вунш), поэтому совпавшие слова
/// (в т.ч. когда где-то сдвиг по длине) не всплывают как ложные ошибки. Правило
/// создаётся только для «подмен похожей длины» — исключая словоформы, числа и
/// фрагменты (когда слово разбилось на два, замена обычного слова была бы вредна).
enum CalibrationAnalyzer {

    private static let minWordLength = 3
    /// Максимальная разница длин слов, чтобы считать это искажением ОДНОГО слова
    /// (а не сплитом/фрагментом типа «после» ← «послезавтра»).
    private static let maxLenDiff = 3

    static func analyze(_ pairs: [CalibrationPair]) -> CalibrationResult {
        var ruleSeen = Set<String>()
        var suggestions: [CorrectionSuggestion] = []

        for pair in pairs {
            let expected = tokenize(pair.expected)
            let heard = tokenize(pair.heard)

            for (e, h) in align(expected, heard) {
                guard let e, let h else { continue }              // пропуск/вставка — не трогаем
                guard e.count >= minWordLength, !h.isEmpty else { continue }
                guard e.lowercased() != h.lowercased() else { continue }
                guard isRealError(expected: e, heard: h) else { continue }
                guard abs(e.count - h.count) <= maxLenDiff else { continue }  // фрагмент/сплит
                let key = h.lowercased()
                if !ruleSeen.contains(key) {
                    ruleSeen.insert(key)
                    suggestions.append(CorrectionSuggestion(pattern: h, replacement: e))
                }
            }
        }

        return CalibrationResult(suggestions: suggestions)
    }

    // MARK: - Выравнивание слов (Нидлман-Вунш)

    /// Возвращает список сопоставлений: (эталон?, распознанное?). nil — пропуск (gap).
    private static func align(_ e: [String], _ h: [String]) -> [(String?, String?)] {
        let n = e.count, m = h.count
        if n == 0 || m == 0 {
            return e.map { ($0, nil) } + h.map { (nil, $0) }
        }
        let gap = -1
        // Счёт диагонали: точное совпадение +2; похожая подмена (общий префикс ≥2)
        // +1 — чтобы выравнивание предпочитало пары «одно слово искажено» (гитхаб↔
        // гидхаб) спарингу с непохожим словом; непохожая подмена −1.
        func diagScore(_ a: String, _ b: String) -> Int {
            let al = a.lowercased(), bl = b.lowercased()
            if al == bl { return 2 }
            return commonPrefixLen(al, bl) >= 2 ? 1 : -1
        }
        var dp = Array(repeating: Array(repeating: 0, count: m + 1), count: n + 1)
        for i in 0...n { dp[i][0] = i * gap }
        for j in 0...m { dp[0][j] = j * gap }
        for i in 1...n {
            for j in 1...m {
                dp[i][j] = max(
                    dp[i - 1][j - 1] + diagScore(e[i - 1], h[j - 1]),
                    dp[i - 1][j] + gap,
                    dp[i][j - 1] + gap
                )
            }
        }
        var ops: [(String?, String?)] = []
        var i = n, j = m
        while i > 0 || j > 0 {
            if i > 0, j > 0 {
                if dp[i][j] == dp[i - 1][j - 1] + diagScore(e[i - 1], h[j - 1]) {
                    ops.append((e[i - 1], h[j - 1])); i -= 1; j -= 1; continue
                }
            }
            if i > 0, dp[i][j] == dp[i - 1][j] + gap {
                ops.append((e[i - 1], nil)); i -= 1
            } else {
                ops.append((nil, h[j - 1])); j -= 1
            }
        }
        return ops.reversed()
    }

    // MARK: - Фильтры

    /// Настоящая ли ошибка (а не словоформа/число). Отсекает: цифры↔слово
    /// («20»↔«двадцать») и однокоренные словоформы («приложений»↔«приложения»).
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
        let cp = commonPrefixLen(a.lowercased(), b.lowercased())
        let maxLen = max(a.count, b.count)
        return cp >= 4 && cp >= maxLen - 3
    }

    private static func commonPrefixLen(_ a: String, _ b: String) -> Int {
        let al = Array(a), bl = Array(b)
        var cp = 0
        while cp < al.count && cp < bl.count && al[cp] == bl[cp] { cp += 1 }
        return cp
    }

    // MARK: - Токенизация

    private static let trimSet = CharacterSet.punctuationCharacters.union(.symbols)

    private static func tokenize(_ s: String) -> [String] {
        s.split(whereSeparator: { $0 == " " || $0 == "\n" || $0 == "\t" })
            .map { $0.trimmingCharacters(in: trimSet) }
            .filter { !$0.isEmpty }
    }
}
