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

    /// Parses a "Week 1 = YYYY-MM-DD" style reference line anywhere in the document.
    /// Korean-worded dates ("2026년 7월 둘째 주") aren't supported — callers should treat
    /// a nil result as "week-relative scheduling unavailable", not an error.
    static func parseWeek1ReferenceDate(inDocument text: String) -> Date? {
        guard let match = firstMatch(in: text, pattern: #"Week\s*1\s*=\s*(\d{4})-(\d{1,2})-(\d{1,2})"#),
              let year = Int(match[1] ?? ""), let month = Int(match[2] ?? ""), let day = Int(match[3] ?? "") else {
            return nil
        }
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar.date(from: components)
    }

    private static func firstMatch(in text: String, pattern: String) -> [Int: String]? {
        RegexUtil.firstMatch(in: text, pattern: pattern)
    }
}
