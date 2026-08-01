import Foundation

enum WeekWindowParser {
    /// Recognizes "W4–9", "W4-9", "W17", "W17+", "Week 4" style labels.
    /// Open-ended windows ("W17+") collapse to a single-week window at that number —
    /// there's no principled end week to infer, and ScheduleEngine treats
    /// single-week windows as "due at end of that week" which is the closest sane reading.
    static func parse(_ raw: String) -> WeekWindow? {
        let text = raw.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }

        if let match = firstMatch(in: text, pattern: #"W(\d+)\s*[–-]\s*(\d+)"#),
           let start = Int(match[1] ?? ""), let end = Int(match[2] ?? "") {
            return WeekWindow(startWeek: start, endWeek: end, rawLabel: text)
        }
        if let match = firstMatch(in: text, pattern: #"Week\s*(\d+)\s*[–-]\s*(\d+)"#),
           let start = Int(match[1] ?? ""), let end = Int(match[2] ?? "") {
            return WeekWindow(startWeek: start, endWeek: end, rawLabel: text)
        }
        if let match = firstMatch(in: text, pattern: #"W(\d+)\+"#),
           let start = Int(match[1] ?? "") {
            return WeekWindow(startWeek: start, endWeek: start, rawLabel: text)
        }
        if let match = firstMatch(in: text, pattern: #"W(\d+)"#),
           let start = Int(match[1] ?? "") {
            return WeekWindow(startWeek: start, endWeek: start, rawLabel: text)
        }
        if let match = firstMatch(in: text, pattern: #"Week\s*(\d+)"#),
           let start = Int(match[1] ?? "") {
            return WeekWindow(startWeek: start, endWeek: start, rawLabel: text)
        }
        return nil
    }

    private static let koreanOrdinals = ["첫째": 1, "둘째": 2, "셋째": 3, "넷째": 4, "다섯째": 5]

    /// Parses a "Week 1 = YYYY-MM-DD" style reference line anywhere in the document, or the
    /// Korean-worded "Week 1 = YYYY년 M월 [첫/둘/셋/넷/다섯]째 주" style used by roadmaps that
    /// state week 1 relative to a calendar month rather than a literal date — resolved as
    /// the Nth Monday of that month (e.g. "2026년 7월 둘째 주" -> the second Monday of July
    /// 2026, 2026-07-13). Callers should treat a nil result as "week-relative scheduling
    /// unavailable", not an error.
    static func parseWeek1ReferenceDate(inDocument text: String) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current

        if let match = firstMatch(in: text, pattern: #"Week\s*1\s*=\s*(\d{4})-(\d{1,2})-(\d{1,2})"#),
           let year = Int(match[1] ?? ""), let month = Int(match[2] ?? ""), let day = Int(match[3] ?? "") {
            var components = DateComponents()
            components.year = year
            components.month = month
            components.day = day
            return calendar.date(from: components)
        }

        if let match = firstMatch(in: text, pattern: #"Week\s*1\s*=\s*(\d{4})년\s*(\d{1,2})월\s*(첫째|둘째|셋째|넷째|다섯째)\s*주"#),
           let year = Int(match[1] ?? ""), let month = Int(match[2] ?? ""),
           let ordinal = koreanOrdinals[match[3] ?? ""] {
            return nthMonday(ordinal: ordinal, year: year, month: month, calendar: calendar)
        }

        return nil
    }

    private static func nthMonday(ordinal: Int, year: Int, month: Int, calendar: Calendar) -> Date? {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        guard let firstOfMonth = calendar.date(from: components) else { return nil }
        // Calendar's `.weekday` is 1=Sunday...7=Saturday; days until the first Monday on/after the 1st.
        let firstWeekday = calendar.component(.weekday, from: firstOfMonth)
        let daysUntilFirstMonday = (2 - firstWeekday + 7) % 7
        let dayOfMonth = 1 + daysUntilFirstMonday + (ordinal - 1) * 7
        return calendar.date(byAdding: .day, value: dayOfMonth - 1, to: firstOfMonth)
    }

    private static func firstMatch(in text: String, pattern: String) -> [Int: String]? {
        RegexUtil.firstMatch(in: text, pattern: pattern)
    }
}
