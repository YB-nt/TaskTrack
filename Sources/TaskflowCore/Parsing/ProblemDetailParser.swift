import Foundation

/// Parses a per-phase "하위 파일" (e.g. `Phase2.md`) that writes up each numbered problem
/// (`### 문제 6-1. ...`) in full — 목표/요구사항/성공 기준/etc. — separately from the
/// terse `tasks.md` subtask row. Keyed by the same `문제 X-Y` token that appears in both
/// files, so a `TaskItem` can be matched to its long-form write-up without the two files
/// needing to agree on anything beyond that shared token.
public enum ProblemDetailParser {
    /// "6-1" -> everything between that problem's `###` heading and the next `##`/`###` heading.
    public static func parse(_ text: String) -> [String: String] {
        let lines = text.components(separatedBy: "\n")
        var result: [String: String] = [:]
        var i = 0
        while i < lines.count {
            let trimmed = lines[i].trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("###"), let id = problemId(in: trimmed) {
                var j = i + 1
                var body: [String] = []
                while j < lines.count, !isHeading(lines[j]) {
                    body.append(lines[j])
                    j += 1
                }
                let joined = body.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                if !joined.isEmpty {
                    result[id] = joined
                }
                i = j
            } else {
                i += 1
            }
        }
        return result
    }

    /// Extracts the `X-Y` token from strings like `### 문제 6-1. ...` (하위 파일 heading)
    /// or `문제 6-1 — 파일 복사 두 벌` (tasks.md subtask row title). Shared so both sides
    /// of the match use the identical rule.
    public static func problemId(in text: String) -> String? {
        RegexUtil.firstMatch(in: text, pattern: #"문제\s+(\d+-\d+)"#)?[1]
    }

    private static func isHeading(_ line: String) -> Bool {
        let t = line.trimmingCharacters(in: .whitespaces)
        return t.hasPrefix("## ") || t.hasPrefix("### ")
    }
}
