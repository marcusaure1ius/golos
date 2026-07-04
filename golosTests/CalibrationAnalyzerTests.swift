import Testing
import Foundation
@testable import golos

@Suite struct CalibrationAnalyzerTests {

    private func pair(_ expected: String, _ heard: String) -> CalibrationPair {
        CalibrationPair(expected: expected, heard: heard)
    }

    @Test func perfectMatchYieldsNothing() {
        let r = CalibrationAnalyzer.analyze([pair("привет как дела", "привет как дела")])
        #expect(r.suggestions.isEmpty)
    }

    @Test func cleanSubstitutionYieldsRule() {
        let r = CalibrationAnalyzer.analyze([pair("открой гитхаб быстро", "открой гидхаб быстро")])
        #expect(r.suggestions == [CorrectionSuggestion(pattern: "гидхаб", replacement: "гитхаб")])
    }

    @Test func catchesCrossScriptAbbreviation() {
        // Аббревиатура: услышанная каша (латиница/фрагмент) → правильное написание.
        let r = CalibrationAnalyzer.analyze([pair("проверь API сегодня", "проверь ап сегодня")])
        #expect(r.suggestions == [CorrectionSuggestion(pattern: "ап", replacement: "API")])
    }

    @Test func skipsNumericMismatch() {
        // Число ↔ слово (20 ↔ двадцать) — не ошибка.
        let r = CalibrationAnalyzer.analyze([pair("через двадцать минут", "через 20 минут")])
        #expect(r.suggestions.isEmpty)
    }

    @Test func skipsInflectionVariant() {
        // Однокоренная словоформа (документы ↔ документов) — не ошибка.
        let r = CalibrationAnalyzer.analyze([pair("открой документы позже", "открой документов позже")])
        #expect(r.suggestions.isEmpty)
    }

    @Test func skipsWordSplitFragment() {
        // Слово разбилось на два («после завтра») — НЕ заменяем обычное слово «после».
        let r = CalibrationAnalyzer.analyze([pair("это послезавтра точно", "это после завтра точно")])
        #expect(r.suggestions.isEmpty)
    }

    @Test func lengthMismatchDoesNotFloodCommonWords() {
        // Пропущено слово «в» — выравнивание сохраняет остальные, ложных правил нет.
        let r = CalibrationAnalyzer.analyze([pair("добавь задачу в бэклог", "добавь задачу бэклог")])
        #expect(r.suggestions.isEmpty)
    }

    @Test func extractsRealErrorAmidLengthMismatch() {
        // Реальная ошибка (гитхаб→гидхаб) находится даже при сдвиге длины (лишнее «там»).
        let r = CalibrationAnalyzer.analyze([pair("открой гитхаб сейчас", "открой гидхаб там сейчас")])
        #expect(r.suggestions == [CorrectionSuggestion(pattern: "гидхаб", replacement: "гитхаб")])
    }

    @Test func ignoresCasingOnlyDifference() {
        let r = CalibrationAnalyzer.analyze([pair("Толк открыт", "толк открыт")])
        #expect(r.suggestions.isEmpty)
    }

    @Test func filtersShortWords() {
        let r = CalibrationAnalyzer.analyze([pair("я и ты", "я и вы")])
        #expect(r.suggestions.isEmpty)
    }

    @Test func dedupesAcrossPairs() {
        let r = CalibrationAnalyzer.analyze([
            pair("открой гитхаб раз", "открой гидхаб раз"),
            pair("снова гитхаб два", "снова гидхаб два"),
        ])
        #expect(r.suggestions == [CorrectionSuggestion(pattern: "гидхаб", replacement: "гитхаб")])
    }

    @Test func stripsPunctuation() {
        let r = CalibrationAnalyzer.analyze([pair("открой гитхаб!", "открой гидхаб!")])
        #expect(r.suggestions == [CorrectionSuggestion(pattern: "гидхаб", replacement: "гитхаб")])
    }

    @Test func emptyInputYieldsNothing() {
        #expect(CalibrationAnalyzer.analyze([]).suggestions.isEmpty)
    }
}
