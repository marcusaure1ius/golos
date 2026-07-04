import Testing
import Foundation
@testable import golos

@Suite struct DictionaryStoreTests {
    private func tmp() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json") }

    @Test func addPersistsAndReloads() async {
        let url = tmp()
        let s = DictionaryStore(fileURL: url)
        await s.add(pattern: "гигаам", replacement: "GigaAM")
        let s2 = DictionaryStore(fileURL: url)            // новый инстанс читает с диска
        let rules = await s2.all()
        #expect(rules.map(\.pattern) == ["гигаам"])
        #expect(rules.map(\.replacement) == ["GigaAM"])
        #expect(rules.first?.enabled == true)
    }

    @Test func preservesInsertionOrder() async {
        let url = tmp()
        let s = DictionaryStore(fileURL: url)
        await s.add(pattern: "a", replacement: "1")
        await s.add(pattern: "b", replacement: "2")
        #expect(await s.all().map(\.pattern) == ["a", "b"])
    }

    @Test func updateReplacesRuleInPlace() async {
        let url = tmp()
        let s = DictionaryStore(fileURL: url)
        await s.add(pattern: "x", replacement: "y")
        var rule = await s.all()[0]
        rule.replacement = "z"
        rule.enabled = false
        await s.update(rule)
        let reloaded = await DictionaryStore(fileURL: url).all()
        #expect(reloaded.count == 1)
        #expect(reloaded[0].replacement == "z")
        #expect(reloaded[0].enabled == false)
    }

    @Test func deleteRemovesRule() async {
        let url = tmp()
        let s = DictionaryStore(fileURL: url)
        await s.add(pattern: "a", replacement: "1")
        let id = await s.all()[0].id
        await s.delete(id: id)
        #expect(await s.all().isEmpty)
    }
}
