import Foundation

/// Детерминированное удаление слов-паразитов / хезитаций из распознанного текста.
///
/// Убирает ТОЛЬКО нелексические заминки («э», «ээ», «э-э», «эм», «мм», «кхм»…),
/// которые почти никогда не являются настоящими словами. Неоднозначные («а», «ну»,
/// «и», «вот») НЕ трогаем — это союзы/частицы, детерминированно удалять их опасно
/// (сломаем «а потом»). Совпадение — по целым словам (Unicode-границы), без учёта
/// регистра. Капитализация первого слова сохраняется по регистру исходного текста.
enum FillerCleaner {

    /// Слова-паразиты и нелексические хезитации. Порядок в alternation — от длинных
    /// к коротким. «ну» — по явной просьбе; матчится только как целое слово (не заденет
    /// «нужно», «ну́жен»).
    private static let fillers = [
        "эмм", "эээ", "ммм", "кхм", "э-э", "м-м",
        "эм", "ээ", "мм", "ну",
        "э",
    ]

    private static let regex: NSRegularExpression = {
        let alts = fillers.map { NSRegularExpression.escapedPattern(for: $0) }.joined(separator: "|")
        // Границы через Unicode-буквы/цифры, чтобы не задеть «эмоция», «мама».
        let pattern = "(?<![\\p{L}\\p{N}])(?:\(alts))(?![\\p{L}\\p{N}])"
        return try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }()

    static func clean(_ text: String) -> String {
        guard !text.isEmpty else { return text }

        let capitalize = firstLetterIsUppercase(text)

        // 1. Вырезаем хезитации.
        var s = regex.stringByReplacingMatches(
            in: text,
            range: NSRange(text.startIndex..., in: text),
            withTemplate: ""
        )

        // 2. Нормализуем пробелы/пунктуацию после вырезания.
        s = replace(s, #"\s{2,}"#, " ")            // двойные пробелы
        s = replace(s, #"\s+([,.!?;:])"#, "$1")    // пробел перед пунктуацией
        s = replace(s, #",(\s*,)+"#, ",")          // серии запятых
        s = replace(s, #"^[\s,]+"#, "")            // мусор в начале
        s = replace(s, #"[\s,]+$"#, "")            // мусор в конце
        s = s.trimmingCharacters(in: .whitespaces)

        if capitalize {
            s = capitalizeFirstLetter(s)
        }
        return s
    }

    // MARK: - Внутреннее

    private static func replace(_ s: String, _ pattern: String, _ template: String) -> String {
        guard let re = try? NSRegularExpression(pattern: pattern) else { return s }
        return re.stringByReplacingMatches(
            in: s, range: NSRange(s.startIndex..., in: s), withTemplate: template
        )
    }

    private static func firstLetterIsUppercase(_ s: String) -> Bool {
        s.first(where: { $0.isLetter })?.isUppercase ?? false
    }

    private static func capitalizeFirstLetter(_ s: String) -> String {
        guard let idx = s.firstIndex(where: { $0.isLetter }) else { return s }
        guard s[idx].isLowercase else { return s }
        return s.replacingCharacters(in: idx...idx, with: s[idx].uppercased())
    }
}
