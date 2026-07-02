import Foundation

/// Дневной бакет статистики: количество диктовок и слов за один календарный день.
struct DayBucket: Codable, Equatable {
    let day: Date          // startOfDay
    var dictations: Int
    var words: Int
}

/// Точка серии по дням.
struct DaySeries: Equatable {
    let date: Date
    let dictations: Int
    let words: Int
}

/// Точка серии по неделям.
struct WeekSeries: Equatable {
    let weekStart: Date
    let dictations: Int
    let words: Int
}

/// Чистые функции агрегации статистики. Не изолированы актором — легко тестируются.
enum StatsAggregator {

    /// Количество слов: разбивка по пробелам и переносам строк.
    static func wordCount(_ text: String) -> Int {
        text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }

    /// Сворачивает записи истории в дневные бакеты (по возрастанию даты).
    static func buckets(from entries: [TranscriptEntry], calendar: Calendar) -> [DayBucket] {
        var map: [Date: DayBucket] = [:]
        for e in entries {
            let day = calendar.startOfDay(for: e.date)
            var b = map[day] ?? DayBucket(day: day, dictations: 0, words: 0)
            b.dictations += 1
            b.words += wordCount(e.text)
            map[day] = b
        }
        return map.values.sorted { $0.day < $1.day }
    }

    /// Последние `count` календарных дней включая сегодня; пропуски — нули. По возрастанию.
    static func lastDays(_ buckets: [DayBucket], count: Int, calendar: Calendar, now: Date) -> [DaySeries] {
        let map = Dictionary(buckets.map { ($0.day, $0) }, uniquingKeysWith: { a, _ in a })
        let today = calendar.startOfDay(for: now)
        return (0..<count).reversed().map { offset in
            let day = calendar.date(byAdding: .day, value: -offset, to: today)!
            let b = map[day]
            return DaySeries(date: day, dictations: b?.dictations ?? 0, words: b?.words ?? 0)
        }
    }

    /// Последние `count` недель включая текущую; выравнивание по `calendar.firstWeekday`. По возрастанию.
    static func lastWeeks(_ buckets: [DayBucket], count: Int, calendar: Calendar, now: Date) -> [WeekSeries] {
        func weekStart(_ d: Date) -> Date { calendar.dateInterval(of: .weekOfYear, for: d)!.start }
        var map: [Date: (dictations: Int, words: Int)] = [:]
        for b in buckets {
            let ws = weekStart(b.day)
            var cur = map[ws] ?? (0, 0)
            cur.dictations += b.dictations
            cur.words += b.words
            map[ws] = cur
        }
        let thisWeek = weekStart(now)
        return (0..<count).reversed().map { offset in
            let ws = calendar.date(byAdding: .weekOfYear, value: -offset, to: thisWeek)!
            let v = map[ws]
            return WeekSeries(weekStart: ws, dictations: v?.dictations ?? 0, words: v?.words ?? 0)
        }
    }

    /// Суммарные тоталы по всем бакетам (за всё время).
    static func totals(_ buckets: [DayBucket]) -> (dictations: Int, words: Int) {
        buckets.reduce(into: (dictations: 0, words: 0)) {
            $0.dictations += $1.dictations
            $0.words += $1.words
        }
    }
}
