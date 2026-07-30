import Foundation

/// Applies targeted, single-line edits to a taskmaster markdown file's raw text, using the
/// `SourceLocation`/`StatusLocation` metadata `TaskMasterMarkdownParser` recorded while
/// parsing. The `.md` file is the single source of truth (see the harness plan) — there is
/// no separate overlay database, so every mutation here rewrites the original file text.
///
/// All functions take and return whole-file text rather than mutating in place, so callers
/// (TaskDocumentStore) can re-parse the result to get a consistent, fresh `TaskDocument`.
public enum TaskFileWriter {
    /// Rewrites the one line that spells out `item`'s status, using whichever of the three
    /// on-disk forms the parser found it in. Returns nil if the item's status wasn't in a
    /// recognizable form (write is simply unavailable for that item — no fallback guess).
    public static func settingStatus(_ status: TaskStatus, for item: TaskItem, in text: String) -> String? {
        guard let location = item.statusLocation else { return nil }
        var lines = text.components(separatedBy: "\n")
        guard location.lineIndex >= 0, location.lineIndex < lines.count else { return nil }
        let line = lines[location.lineIndex]

        switch location.kind {
        case .fencedField:
            guard let replaced = replacingCapturedValue(in: line, pattern: #"^(#\s*Status:\s*).*$"#, newValue: status.rawValue) else {
                return nil
            }
            lines[location.lineIndex] = replaced
        case .inlineBacktickAfterBold:
            guard let replaced = replacingFirst(in: line, pattern: #"`[A-Za-z-]+`"#, with: "`\(status.rawValue)`") else {
                return nil
            }
            lines[location.lineIndex] = replaced
        case .tableRow:
            guard let columnIndex = location.tableColumnIndex,
                  let replaced = replacingTableCell(in: line, columnIndex: columnIndex, newValue: status.rawValue) else {
                return nil
            }
            lines[location.lineIndex] = replaced
        }
        return lines.joined(separator: "\n")
    }

    /// Flips a Test Strategy checklist line between `- [ ]` and `- [x]`.
    public static func togglingChecklistItem(_ item: ChecklistItem, in text: String) -> String {
        var lines = text.components(separatedBy: "\n")
        guard item.lineIndex >= 0, item.lineIndex < lines.count else { return text }
        let newMark = item.checked ? " " : "x"
        if let replaced = replacingFirst(in: lines[item.lineIndex], pattern: #"^(-\s*\[)[ xX](\])"#, with: "$1\(newMark)$2", isTemplate: true) {
            lines[item.lineIndex] = replaced
        }
        return lines.joined(separator: "\n")
    }

    /// Appends a timestamped note under `task`'s Details section (or right after the task's
    /// own header line if it has no Details section at all — a fresh "**Details**" header is
    /// not synthesized here to keep this a pure append; the note still ends up readably close
    /// to the task). Mirrors the spirit of `task-master update-subtask --prompt=...`.
    public static func appendingDetailNote(_ note: String, to task: TaskItem, in text: String, timestamp: Date = Date()) -> String {
        var lines = text.components(separatedBy: "\n")
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        let stamped = "- (\(formatter.string(from: timestamp))) \(note)"

        let insertAt = min((task.detailsAppendLineIndex ?? -1) + 1, lines.count)
        lines.insert(stamped, at: max(0, insertAt))
        return lines.joined(separator: "\n")
    }

    // MARK: - Line-level regex helpers

    private static func replacingCapturedValue(in line: String, pattern: String, newValue: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsLine = line as NSString
        guard let match = regex.firstMatch(in: line, range: NSRange(location: 0, length: nsLine.length)) else { return nil }
        let prefixRange = match.range(at: 1)
        guard prefixRange.location != NSNotFound else { return nil }
        let prefix = nsLine.substring(with: prefixRange)
        return prefix + newValue
    }

    private static func replacingFirst(in line: String, pattern: String, with replacementTemplate: String, isTemplate: Bool = false) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsLine = line as NSString
        let range = NSRange(location: 0, length: nsLine.length)
        guard regex.firstMatch(in: line, range: range) != nil else { return nil }
        if isTemplate {
            return regex.stringByReplacingMatches(in: line, range: range, withTemplate: replacementTemplate)
        }
        // Non-template mode: replace only the first match, verbatim (no $1-style expansion).
        guard let match = regex.firstMatch(in: line, range: range) else { return nil }
        return nsLine.replacingCharacters(in: match.range, with: replacementTemplate)
    }

    private static func replacingTableCell(in line: String, columnIndex: Int, newValue: String) -> String? {
        var trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("|") else { return nil }
        let hadTrailingPipe = trimmed.hasSuffix("|")
        if trimmed.hasPrefix("|") { trimmed.removeFirst() }
        if hadTrailingPipe { trimmed.removeLast() }
        var cells = trimmed.components(separatedBy: "|")
        guard columnIndex >= 0, columnIndex < cells.count else { return nil }
        let cellText = cells[columnIndex]
        let leadingSpace = cellText.prefix(while: { $0 == " " })
        let trailingSpace = cellText.reversed().prefix(while: { $0 == " " }).reversed()
        cells[columnIndex] = "\(leadingSpace)\(newValue)\(trailingSpace)"
        let rebuilt = cells.joined(separator: "|")
        return "|\(rebuilt)\(hadTrailingPipe ? "|" : "")"
    }
}
