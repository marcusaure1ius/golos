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
        let cal = Calendar(identifier: .gregorian)
        let now = Date(timeIntervalSince1970: 100 * 86400 + 3600)
        let today = TranscriptEntry(id: UUID(), text: "t", date: now)
        let yest = TranscriptEntry(id: UUID(), text: "y", date: now.addingTimeInterval(-86400))
        let g = HistoryStore.grouped([yest, today], calendar: cal, now: now)
        #expect(g.first?.label == "Сегодня")
        #expect(g.first?.items.first?.text == "t")
    }
}
