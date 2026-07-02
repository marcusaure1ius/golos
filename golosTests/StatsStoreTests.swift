import Testing
import Foundation
@testable import golos

@Suite struct StatsStoreTests {
    private func tmp() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
    }

    @Test func recordPersistsAndReloads() async {
        let url = tmp()
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        let s = StatsStore(fileURL: url)
        await s.record(wordCount: 3, date: day)
        await s.record(wordCount: 2, date: day.addingTimeInterval(3600))   // тот же день
        let s2 = StatsStore(fileURL: url)                                  // новый инстанс читает с диска
        let snap = await s2.snapshot()
        #expect(snap.count == 1)
        #expect(snap[0].dictations == 2)
        #expect(snap[0].words == 5)
    }

    @Test func recordSeparateDays() async {
        let url = tmp()
        let d1 = Date(timeIntervalSince1970: 1_700_000_000)
        let d2 = d1.addingTimeInterval(48 * 3600)
        let s = StatsStore(fileURL: url)
        await s.record(wordCount: 1, date: d1)
        await s.record(wordCount: 1, date: d2)
        #expect(await s.snapshot().count == 2)
    }

    @Test func seedFromHistoryOnce() async {
        let url = tmp()
        let d = Date(timeIntervalSince1970: 1_700_000_000)
        let entries = [
            TranscriptEntry(id: UUID(), text: "два слова", date: d),
            TranscriptEntry(id: UUID(), text: "три коротких слова", date: d.addingTimeInterval(3600)),
        ]
        let s = StatsStore(fileURL: url)
        await s.seedIfNeeded(from: entries)
        let snap = await s.snapshot()
        #expect(snap.count == 1)
        #expect(snap[0].dictations == 2)
        #expect(snap[0].words == 5)

        // Повторный сидинг ничего не меняет (флаг выставлен).
        await s.seedIfNeeded(from: [TranscriptEntry(id: UUID(), text: "лишнее", date: d)])
        #expect(await s.snapshot()[0].dictations == 2)
    }

    @Test func seedSkippedIfAlreadyRecorded() async {
        let url = tmp()
        let d = Date(timeIntervalSince1970: 1_700_000_000)
        let s = StatsStore(fileURL: url)
        await s.record(wordCount: 4, date: d)                 // запись раньше сидинга
        await s.seedIfNeeded(from: [TranscriptEntry(id: UUID(), text: "a b c", date: d)])
        let snap = await s.snapshot()
        #expect(snap.count == 1)
        #expect(snap[0].dictations == 1)                      // сидинг не задвоил
        #expect(snap[0].words == 4)
    }
}
