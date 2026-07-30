import Foundation

/// Small regex helpers shared by the parser modules. Kept as plain NSRegularExpression
/// wrappers (rather than Swift's Regex literals) so pattern strings stay easy to log/debug.
enum RegexUtil {
    /// Capture groups 1...n of the first match anywhere in `text`, or nil if no match.
    static func firstMatch(in text: String, pattern: String, options: NSRegularExpression.Options = []) -> [Int: String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return nil }
        let nsText = text as NSString
        guard let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: nsText.length)) else {
            return nil
        }
        return captureGroups(match, in: nsText)
    }

    /// True if `pattern` matches anywhere in `line` (used for boundary/predicate checks).
    static func matches(_ line: String, pattern: String) -> Bool {
        firstMatch(in: line, pattern: pattern) != nil
    }

    /// Capture groups 1...n for every match in `text`, in order.
    static func allMatches(in text: String, pattern: String, options: NSRegularExpression.Options = []) -> [[Int: String]] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return [] }
        let nsText = text as NSString
        let all = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        return all.map { captureGroups($0, in: nsText) }
    }

    private static func captureGroups(_ match: NSTextCheckingResult, in nsText: NSString) -> [Int: String] {
        var groups: [Int: String] = [:]
        for i in 1..<match.numberOfRanges {
            let range = match.range(at: i)
            if range.location != NSNotFound {
                groups[i] = nsText.substring(with: range)
            }
        }
        return groups
    }
}
