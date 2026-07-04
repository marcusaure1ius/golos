import Foundation

/// Детерминированная постобработка распознанного текста по пользовательскому словарю.
///
/// Заменяет целые слова/фразы без учёта регистра. Правила применяются по порядку,
/// каждое видит результат предыдущего. Замена — по границам слов (Unicode-буквы/цифры),
/// поэтому `код` не трогает `кодировка`. Если совпадение начиналось с заглавной, а
/// замена — со строчной буквы, первая буква замены поднимается в верхний регистр
/// (чтобы правки обычных слов в начале предложения сохраняли заглавную).
enum TranscriptCorrector {

    static func apply(_ text: String, rules: [DictionaryRule]) -> String {
        var result = text
        for rule in rules where rule.enabled && !rule.pattern.isEmpty {
            result = applyRule(result, pattern: rule.pattern, replacement: rule.replacement)
        }
        return result
    }

    // MARK: - Внутреннее

    private static func isWordChar(_ c: Character) -> Bool {
        c.isLetter || c.isNumber
    }

    private static func applyRule(_ s: String, pattern: String, replacement: String) -> String {
        let chars = Array(s)
        let pat = Array(pattern.lowercased())
        let n = chars.count
        let m = pat.count
        guard m > 0, n >= m else { return s }

        var out: [Character] = []
        out.reserveCapacity(n)
        var i = 0
        while i < n {
            if i + m <= n && matches(chars, at: i, pattern: pat)
                && (i == 0 || !isWordChar(chars[i - 1]))
                && (i + m == n || !isWordChar(chars[i + m])) {
                out.append(contentsOf: cased(replacement, likeMatchStart: chars[i]))
                i += m
            } else {
                out.append(chars[i])
                i += 1
            }
        }
        return String(out)
    }

    /// Case-insensitive сравнение среза `chars[i..<i+m]` с уже-строчным `pat`.
    private static func matches(_ chars: [Character], at i: Int, pattern pat: [Character]) -> Bool {
        for k in 0..<pat.count where String(chars[i + k]).lowercased() != String(pat[k]) {
            return false
        }
        return true
    }

    /// Если совпадение начиналось с заглавной, а замена — со строчной буквы,
    /// поднять первую букву замены. Иначе — замена дословно.
    private static func cased(_ replacement: String, likeMatchStart matched: Character) -> [Character] {
        var rep = Array(replacement)
        if matched.isUppercase, let first = rep.first, first.isLowercase {
            rep[0] = Character(String(first).uppercased())
        }
        return rep
    }
}
