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
        let r = CalibrationAnalyzer.analyze([pair("позвони Денису", "позвони денисы")])
        #expect(r.biasTerms == ["Денису"])
    }

    @Test func dedupesAcrossPairs() {
        let r = CalibrationAnalyzer.analyze([
            pair("открой гитхаб", "открой гидхаб"),
            pair("снова гитхаб", "снова гид хаб"),
        ])
        #expect(r.biasTerms == ["гитхаб"])
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
