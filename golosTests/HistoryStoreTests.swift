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

    @Test func capKeepsNewest100AndEvictsOldest() async {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        let s = HistoryStore(fileURL: url)
        for i in 0..<101 { await s.add(text: "msg\(i)", date: Date(timeIntervalSince1970: Double(i))) }
        let all = await s.all()
        #expect(all.count == 100)
        #expect(all.first?.text == "msg100")        // newest kept
        #expect(all.contains { $0.text == "msg0" } == false)  // oldest evicted
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
