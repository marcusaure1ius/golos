import Testing
import Foundation
@testable import golos

@Suite struct CalibrationAnalyzerTests {

    private func pair(_ expected: String, _ heard: String) -> CalibrationPair {
        CalibrationPair(expected: expected, heard: heard)
    }

    @Test func perfectMatchYieldsNothing() {
        let r = CalibrationAnalyzer.analyze([pair("привет как дела", "привет как дела")])
        #expect(r.biasTerms.isEmpty)
        #expect(r.suggestions.isEmpty)
    }

    @Test func missingWordBecomesBiasTerm() {
        // «послезавтра» модель разбила на «после завтра» → слова нет как есть → в bias.
        let r = CalibrationAnalyzer.analyze([pair("давай встретимся послезавтра", "давай встретимся после завтра")])
        #expect(r.biasTerms == ["послезавтра"])
    }

    @Test func substitutionYieldsRuleWithoutDuplicateBias() {
        // Слово покрыто правилом замены → отдельный bias-термин не дублируем
        // (правило само биасит по «заменить на»).
        let r = CalibrationAnalyzer.analyze([pair("открой гитхаб", "открой гидхаб")])
        #expect(r.suggestions == [CorrectionSuggestion(pattern: "гидхаб", replacement: "гитхаб")])
        #expect(r.biasTerms.isEmpty)
    }

    @Test func missingWordStaysBiasOnlyWhenNoRule() {
        // Слово пропало (разная длина фраз, правила нет) → остаётся чистым bias-термином.
        let r = CalibrationAnalyzer.analyze([pair("это послезавтра точно", "это после завтра точно")])
        #expect(r.biasTerms == ["послезавтра"])
        #expect(r.suggestions.isEmpty)
    }

    @Test func ignoresCasingOnlyDifference() {
        // Отличие только регистром — это не «неправильное слово».
        let r = CalibrationAnalyzer.analyze([pair("Толк открыт", "толк открыт")])
        #expect(r.biasTerms.isEmpty)
        #expect(r.suggestions.isEmpty)
    }

    @Test func filtersShortWords() {
        // Короткие слова (≤2) — шум, не биасим.
        let r = CalibrationAnalyzer.analyze([pair("я и ты", "я и вы")])
        #expect(r.biasTerms.isEmpty)
    }

    @Test func preservesExpectedCasingInBiasTerm() {
        // Полностью пропущенное слово (разная длина → правила нет) сохраняет регистр.
        let r = CalibrationAnalyzer.analyze([pair("позвони Денису вечером", "позвони вечером")])
        #expect(r.biasTerms == ["Денису"])
        #expect(r.suggestions.isEmpty)
    }

    @Test func skipsNumericMismatch() {
        // Число ↔ слово (20 ↔ двадцать) — не ошибка, не предлагаем.
        let r = CalibrationAnalyzer.analyze([pair("через двадцать минут", "через 20 минут")])
        #expect(r.suggestions.isEmpty)
        #expect(r.biasTerms.isEmpty)
    }

    @Test func skipsInflectionVariant() {
        // Однокоренная словоформа (приложения ↔ приложений) — не ошибка.
        let r = CalibrationAnalyzer.analyze([pair("открой документы позже", "открой документов позже")])
        #expect(r.suggestions.isEmpty)
        #expect(r.biasTerms.isEmpty)
    }

    @Test func keepsRealMidWordError() {
        // Расхождение в середине (гидхаб ↔ гитхаб) — настоящая ошибка, оставляем.
        let r = CalibrationAnalyzer.analyze([pair("открой гитхаб быстро", "открой гидхаб быстро")])
        #expect(r.suggestions == [CorrectionSuggestion(pattern: "гидхаб", replacement: "гитхаб")])
    }

    @Test func dedupesMissingWordAcrossPairs() {
        let r = CalibrationAnalyzer.analyze([
            pair("это послезавтра точно", "это после завтра точно"),
            pair("снова послезавтра там", "снова после завтра там"),
        ])
        #expect(r.biasTerms == ["послезавтра"])
    }

    @Test func stripsPunctuation() {
        let r = CalibrationAnalyzer.analyze([pair("это послезавтра!", "это после завтра!")])
        #expect(r.biasTerms == ["послезавтра"])
    }

    @Test func emptyInputYieldsNothing() {
        let r = CalibrationAnalyzer.analyze([])
        #expect(r.biasTerms.isEmpty)
        #expect(r.suggestions.isEmpty)
    }
}
