import Testing
import Foundation
@testable import golos

@Suite struct HistoryStoreTests {
    private func tmp() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json") }

    @Test func addPersistsAndReloads() async {
        let url = tmp()
        let s = HistoryStore(fileURL: url)
        await s.add(text: "привет", date: Date(timeIntervalSince1970: 1000))
        let s2 = HistoryStore(fileURL: url)               // новый инстанс читает с диска
        #expect(await s2.all().map(\.text) == ["привет"])
    }

    @Test func pruneDropsOld() async {
        let url = tmp()
        let s = HistoryStore(fileURL: url)
        let now = Date(timeIntervalSince1970: 100 * 86400)
        await s.add(text: "old", date: now.addingTimeInterval(-40 * 86400))
        await s.add(text: "new", date: now.addingTimeInterval(-1 * 86400))
        await s.prune(retentionDays: 30, now: now)
        #expect(await s.all().map(\.text) == ["new"])
    }

    @Test func pruneZeroKeepsAll() async {
        let url = tmp()
        let s = HistoryStore(fileURL: url)
        await s.add(text: "x", date: Date(timeIntervalSince1970: 0))
        await s.prune(retentionDays: 0, now: Date())
        #expect(await s.all().count == 1)
    }

    @Test func searchSubstringCaseInsensitive() async {
        let url = tmp()
        let s = HistoryStore(fileURL: url)
        await s.add(text: "Привет Мир", date: Date())
        await s.add(text: "пока", date: Date())
        #expect(await s.search("мир").count == 1)
    }

    @Test func groupingTodayYesterday() {
        let cal = Calendar.current
        let now = Date()
        let today = TranscriptEntry(id: UUID(), text: "t", date: now)
        let yest = TranscriptEntry(id: UUID(), text: "y", date: cal.date(byAdding: .day, value: -1, to: now)!)
        let g = HistoryStore.grouped([yest, today], calendar: cal, now: now)
        #expect(g.count == 2)
        #expect(g.first?.label == "Сегодня")
        #expect(g.first?.items.first?.text == "t")
        #expect(g[1].label == "Вчера")
        #expect(g[1].items.first?.text == "y")
    }

    @Test func deleteRemovesById() async {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        let s = HistoryStore(fileURL: url)
        await s.add(text: "a", date: Date(timeIntervalSince1970: 1))
        await s.add(text: "b", date: Date(timeIntervalSince1970: 2))
        let toDelete = await s.all().first { $0.text == "a" }!.id
        await s.delete(id: toDelete)
        #expect(await s.all().map(\.text) == ["b"])
    }
}
