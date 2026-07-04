import Testing
import Foundation
@testable import golos

@Suite struct TranscriptCorrectorTests {

    private func rule(_ pattern: String, _ replacement: String, enabled: Bool = true) -> DictionaryRule {
        DictionaryRule(id: UUID(), pattern: pattern, replacement: replacement, enabled: enabled)
    }

    // MARK: - Базовая замена

    @Test func replacesWholeWordCaseInsensitive() {
        let out = TranscriptCorrector.apply("я открыл гигаам вчера", rules: [rule("гигаам", "GigaAM")])
        #expect(out == "я открыл GigaAM вчера")
    }

    @Test func replacesAllOccurrences() {
        let out = TranscriptCorrector.apply("код код кода", rules: [rule("код", "code")])
        // "кода" — не отдельное слово, не трогаем
        #expect(out == "code code кода")
    }

    // MARK: - Границы слова

    @Test func doesNotReplaceInsideLongerWord() {
        let out = TranscriptCorrector.apply("кодировка", rules: [rule("код", "code")])
        #expect(out == "кодировка")
    }

    @Test func latinWordBoundary() {
        let out = TranscriptCorrector.apply("commit и commits", rules: [rule("commit", "коммит")])
        #expect(out == "коммит и commits")
    }

    // MARK: - Фразы из нескольких слов

    @Test func replacesMultiWordPhrase() {
        let out = TranscriptCorrector.apply("еду в нью йорк завтра", rules: [rule("нью йорк", "Нью-Йорк")])
        #expect(out == "еду в Нью-Йорк завтра")
    }

    // MARK: - Регистр

    @Test func preservesLeadingCapitalWhenMatchCapitalized() {
        // Замена обычного слова в начале предложения сохраняет заглавную.
        let out = TranscriptCorrector.apply("Каторый час?", rules: [rule("каторый", "который")])
        #expect(out == "Который час?")
    }

    @Test func brandCasingStaysVerbatimWhenMatchLowercase() {
        let out = TranscriptCorrector.apply("формат онникс", rules: [rule("онникс", "ONNX")])
        #expect(out == "формат ONNX")
    }

    @Test func brandCasingNotDoubledWhenMatchCapitalized() {
        let out = TranscriptCorrector.apply("Онникс быстрый", rules: [rule("онникс", "ONNX")])
        #expect(out == "ONNX быстрый")
    }

    // MARK: - Правила

    @Test func skipsDisabledRule() {
        let out = TranscriptCorrector.apply("гигаам", rules: [rule("гигаам", "GigaAM", enabled: false)])
        #expect(out == "гигаам")
    }

    @Test func ignoresEmptyPattern() {
        let out = TranscriptCorrector.apply("текст", rules: [rule("", "X")])
        #expect(out == "текст")
    }

    @Test func rulesComposeInOrder() {
        let rules = [rule("сайдкар", "sidecar"), rule("sidecar", "**sidecar**")]
        let out = TranscriptCorrector.apply("запусти сайдкар", rules: rules)
        #expect(out == "запусти **sidecar**")
    }

    @Test func emptyRulesReturnsInput() {
        #expect(TranscriptCorrector.apply("без изменений", rules: []) == "без изменений")
    }
}
