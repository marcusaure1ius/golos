import Testing
import Foundation
@testable import golos

@Suite struct StatsAggregatorTests {

    @Test func wordCountVariants() {
        #expect(StatsAggregator.wordCount("") == 0)
        #expect(StatsAggregator.wordCount("   ") == 0)
        #expect(StatsAggregator.wordCount("привет") == 1)
        #expect(StatsAggregator.wordCount("  привет   мир  ") == 2)
        #expect(StatsAggregator.wordCount("одна\nдве\tтри") == 3)
    }

    @Test func bucketsAggregatePerDay() {
        let cal = Calendar.current
        let d1 = Date(timeIntervalSince1970: 1_700_000_000)          // день A
        let d1b = d1.addingTimeInterval(3600)                        // тот же день
        let d2 = d1.addingTimeInterval(48 * 3600)                    // день B (+2 сут)
        let entries = [
            TranscriptEntry(id: UUID(), text: "два слова", date: d1),
            TranscriptEntry(id: UUID(), text: "ещё три коротких", date: d1b),
            TranscriptEntry(id: UUID(), text: "один", date: d2),
        ]
        let b = StatsAggregator.buckets(from: entries, calendar: cal)
        #expect(b.count == 2)
        #expect(b[0].dictations == 2)          // день A: 2 диктовки
        #expect(b[0].words == 5)               // 2 + 3 слова
        #expect(b[1].dictations == 1)
        #expect(b[1].words == 1)
        #expect(b[0].day < b[1].day)           // по возрастанию
    }

    @Test func lastDaysFillsGapsWithZeros() {
        let cal = Calendar.current
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let today = cal.startOfDay(for: now)
        let buckets = [DayBucket(day: today, dictations: 4, words: 20)]
        let series = StatsAggregator.lastDays(buckets, count: 7, calendar: cal, now: now)
        #expect(series.count == 7)
        #expect(series.last?.dictations == 4)          // сегодня — последний элемент
        #expect(series.dropLast().allSatisfy { $0.dictations == 0 })
        #expect(series[0].date < series[6].date)       // по возрастанию
    }

    @Test func lastWeeksAlignsToFirstWeekday() {
        var cal = Calendar.current
        cal.firstWeekday = 2                           // понедельник
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let thisWeek = cal.dateInterval(of: .weekOfYear, for: now)!.start
        let buckets = [DayBucket(day: cal.startOfDay(for: now), dictations: 3, words: 9)]
        let series = StatsAggregator.lastWeeks(buckets, count: 7, calendar: cal, now: now)
        #expect(series.count == 7)
        #expect(series.last?.weekStart == thisWeek)
        #expect(series.last?.dictations == 3)
        #expect(series.dropLast().allSatisfy { $0.dictations == 0 })
    }

    @Test func totalsSumAllBuckets() {
        let cal = Calendar.current
        let t0 = cal.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
        let t1 = cal.date(byAdding: .day, value: 1, to: t0)!
        let buckets = [
            DayBucket(day: t0, dictations: 2, words: 10),
            DayBucket(day: t1, dictations: 3, words: 15),
        ]
        let tot = StatsAggregator.totals(buckets)
        #expect(tot.dictations == 5)
        #expect(tot.words == 25)
    }
}
