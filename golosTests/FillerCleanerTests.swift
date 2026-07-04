import Testing
import Foundation
@testable import golos

@Suite struct FillerCleanerTests {

    @Test func removesStandaloneHesitation() {
        #expect(FillerCleaner.clean("э-э привет") == "привет")
        #expect(FillerCleaner.clean("привет ээ мир") == "привет мир")
    }

    @Test func caseInsensitive() {
        // Оригинал начинался с заглавной → первое слово результата поднимается.
        #expect(FillerCleaner.clean("Эм, привет") == "Привет")
    }

    @Test func removesMultipleFillers() {
        #expect(FillerCleaner.clean("вот э-э мм давай") == "вот давай")
    }

    @Test func removesNuAsWholeWord() {
        #expect(FillerCleaner.clean("ну давай пойдём") == "давай пойдём")
        #expect(FillerCleaner.clean("Ну ладно") == "Ладно")
        // Не трогает слова, где «ну» — часть слова.
        #expect(FillerCleaner.clean("нужно это сделать") == "нужно это сделать")
    }

    @Test func doesNotTouchRealWordsContainingFillerLetters() {
        // «эмоция», «мама» содержат буквы хезитаций, но это целые слова — не трогаем.
        #expect(FillerCleaner.clean("эмоция и мама") == "эмоция и мама")
    }

    @Test func doesNotRemoveAmbiguousConjunctionA() {
        // «а» — союз, детерминированно удалять нельзя.
        #expect(FillerCleaner.clean("а потом пошли") == "а потом пошли")
    }

    @Test func fixesSpacingAfterRemoval() {
        #expect(FillerCleaner.clean("слово  э-э  слово") == "слово слово")
    }

    @Test func dropsOrphanCommaFromRemovedFiller() {
        #expect(FillerCleaner.clean("э-э, привет") == "привет")
        #expect(FillerCleaner.clean("привет, мм, как дела") == "привет, как дела")
    }

    @Test func capitalizesFirstWordIfSentenceStartFillerRemoved() {
        #expect(FillerCleaner.clean("Ээ, давай встретимся") == "Давай встретимся")
    }

    @Test func emptyAndCleanTextUnchanged() {
        #expect(FillerCleaner.clean("") == "")
        #expect(FillerCleaner.clean("привет мир") == "привет мир")
    }

    @Test func allFillersLeavesEmpty() {
        #expect(FillerCleaner.clean("э-э мм ээ") == "")
    }
}
