import Foundation

/// Parses a taskmaster-format markdown file (as produced by the `task-master` CLI, or
/// hand-authored in the same convention) into a `TaskDocument`.
///
/// The nesting depth isn't fixed: `tasks.md`-style files go Task → Subtask (2 levels),
/// `tasks_v2.md`-style files add a per-subtask breakdown table (3 levels). The parser
/// treats `children` as arbitrary-depth rather than assuming a fixed schema, so it
/// doesn't need to change when a file grows more detail later.
public enum TaskMasterMarkdownParser {
    public static func parse(_ text: String) -> TaskDocument {
        let lines = text.components(separatedBy: "\n")

        let projectName = lineValue(lines: lines, boldKey: "Project")
        let sourceLabel = lineValue(lines: lines, boldKey: "Source")
        let timelineRaw = lineValue(lines: lines, boldKey: "Timeline")
        let week1ReferenceDate = WeekWindowParser.parseWeek1ReferenceDate(inDocument: text)
        let windowByTaskId = parseTaskListWindows(lines: lines)

        var tasks: [TaskItem] = []
        var i = 0
        while i < lines.count {
            if topLevelTaskId(lines[i]) != nil {
                let blockEnd = findBlockEnd(from: i + 1, lines: lines)
                var item = parseTaskBlock(lines: lines, headerIndex: i, blockEnd: blockEnd)
                if item.window == nil, let raw = windowByTaskId[item.id] {
                    item.window = WeekWindowParser.parse(raw)
                }
                tasks.append(item)
                i = blockEnd
            } else {
                i += 1
            }
        }

        let withInheritedPriority = tasks.map { inheritPriority($0, fallback: nil) }
        return TaskDocument(
            projectName: projectName,
            sourceLabel: sourceLabel,
            timelineRaw: timelineRaw,
            week1ReferenceDate: week1ReferenceDate,
            tasks: withInheritedPriority,
            rawText: text
        )
    }

    // MARK: - Top-level task blocks

    private static func topLevelTaskId(_ line: String) -> String? {
        RegexUtil.firstMatch(in: line, pattern: #"^##\s+Task\s+(\d+(?:\.\d+)*)\b"#)?[1]
    }

    private static func findBlockEnd(from start: Int, lines: [String]) -> Int {
        var i = start
        while i < lines.count {
            if topLevelTaskId(lines[i]) != nil { return i }
            if RegexUtil.matches(lines[i], pattern: #"^##\s+Appendix"#) { return i }
            i += 1
        }
        return lines.count
    }

    private static func parseTaskListWindows(lines: [String]) -> [String: String] {
        guard let headingIdx = lines.firstIndex(where: { RegexUtil.matches($0, pattern: #"^##\s+Task List"#) }) else {
            return [:]
        }
        var i = headingIdx + 1
        while i < lines.count, !lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("|") {
            i += 1
        }
        guard i < lines.count, let table = parseTable(lines: lines, headerIndex: i) else { return [:] }
        guard let idCol = table.columns.firstIndex(where: { $0.uppercased() == "ID" }),
              let windowCol = table.columns.firstIndex(where: { $0.uppercased().contains("WINDOW") }) else {
            return [:]
        }
        var result: [String: String] = [:]
        for row in table.rows where idCol < row.cells.count && windowCol < row.cells.count {
            result[row.cells[idCol]] = row.cells[windowCol]
        }
        return result
    }

    private static func parseTaskBlock(lines: [String], headerIndex: Int, blockEnd: Int) -> TaskItem {
        var fenceStartIdx: Int?
        var fenceEndIdx: Int?
        var i = headerIndex + 1
        while i < blockEnd {
            if lines[i].trimmingCharacters(in: .whitespaces) == "```" {
                if fenceStartIdx == nil { fenceStartIdx = i } else { fenceEndIdx = i; break }
            }
            i += 1
        }

        var idFromFence: String?
        var titleFromFence: String?
        var status: TaskStatus = .pending
        var statusLocation: StatusLocation?
        var priority: Priority?
        var dependencies: [String] = []

        if let fs = fenceStartIdx, let fe = fenceEndIdx, fe > fs {
            for line in (fs + 1)..<fe {
                guard let m = RegexUtil.firstMatch(in: lines[line], pattern: #"^#\s*([^:]+):\s*(.*)$"#) else { continue }
                let key = (m[1] ?? "").trimmingCharacters(in: .whitespaces).lowercased()
                let value = (m[2] ?? "").trimmingCharacters(in: .whitespaces)
                switch key {
                case "task id": idFromFence = value
                case "title": titleFromFence = value
                case "status":
                    status = TaskStatus(rawValue: value.lowercased()) ?? .pending
                    statusLocation = StatusLocation(lineIndex: line, kind: .fencedField)
                case "priority": priority = Priority(rawValue: value.lowercased())
                case "dependencies": dependencies = parseDependencies(value)
                default: break
                }
            }
        }

        let headerMatch = RegexUtil.firstMatch(in: lines[headerIndex], pattern: #"^##\s+Task\s+(\d+(?:\.\d+)*)\s*—\s*(.*)$"#)
        let id = idFromFence ?? headerMatch?[1] ?? "?"
        let title = titleFromFence ?? headerMatch?[2]?.trimmingCharacters(in: .whitespaces) ?? id

        var pointer = (fenceEndIdx ?? headerIndex) + 1
        var description: String?
        var details: String?
        var detailsAppendLineIndex: Int?
        var testStrategy: [ChecklistItem] = []
        var children: [TaskItem] = []

        while pointer < blockEnd {
            switch sectionKind(of: lines[pointer]) {
            case "description":
                let (body, endIdx, _) = captureSection(lines: lines, start: pointer + 1, end: blockEnd)
                description = body.isEmpty ? nil : body
                pointer = endIdx
            case "details":
                let (body, endIdx, lastNonBlank) = captureSection(lines: lines, start: pointer + 1, end: blockEnd)
                details = body.isEmpty ? nil : body
                detailsAppendLineIndex = lastNonBlank ?? pointer
                pointer = endIdx
            case "testStrategy":
                let (items, endIdx) = captureChecklist(lines: lines, start: pointer + 1, end: blockEnd)
                testStrategy = items
                pointer = endIdx
            case "subtasks":
                children = parseSubtasks(lines: lines, start: pointer + 1, end: blockEnd)
                pointer = blockEnd
            default:
                pointer += 1
            }
        }

        return TaskItem(
            id: id,
            title: title,
            status: status,
            priority: priority,
            dependencies: dependencies,
            window: nil,
            description: description,
            details: details,
            testStrategy: testStrategy,
            children: children,
            statusLocation: statusLocation,
            detailsAppendLineIndex: detailsAppendLineIndex
        )
    }

    // MARK: - Subtasks

    private static func isSubtaskHeader(_ line: String) -> Bool {
        RegexUtil.matches(line, pattern: #"^\*\*(\d+(?:\.\d+)*)\s+—\s+(.+)\*\*"#)
    }

    private static func parseSubtasks(lines: [String], start: Int, end: Int) -> [TaskItem] {
        var headerIdxs: [Int] = []
        var i = start
        while i < end {
            if isSubtaskHeader(lines[i]) { headerIdxs.append(i) }
            i += 1
        }
        return headerIdxs.enumerated().compactMap { offset, headerIdx in
            let bodyEnd = offset + 1 < headerIdxs.count ? headerIdxs[offset + 1] : end
            return parseSubtaskEntry(lines: lines, headerIndex: headerIdx, bodyEnd: bodyEnd)
        }
    }

    private static func parseSubtaskEntry(lines: [String], headerIndex: Int, bodyEnd: Int) -> TaskItem? {
        guard let m = RegexUtil.firstMatch(in: lines[headerIndex], pattern: #"^\*\*(\d+(?:\.\d+)*)\s+—\s+(.+)\*\*(.*)$"#) else {
            return nil
        }
        let id = m[1] ?? ""
        let title = (m[2] ?? "").trimmingCharacters(in: .whitespaces)
        let remainder = m[3] ?? ""

        var status: TaskStatus = .pending
        var statusLocation: StatusLocation?
        if let sm = RegexUtil.firstMatch(in: remainder, pattern: #"`([A-Za-z-]+)`"#) {
            status = TaskStatus(rawValue: (sm[1] ?? "").lowercased()) ?? .pending
            statusLocation = StatusLocation(lineIndex: headerIndex, kind: .inlineBacktickAfterBold)
        }

        var dependencies: [String] = []
        if let dm = RegexUtil.firstMatch(in: remainder, pattern: #"(?i)deps:\s*(.*)$"#) {
            dependencies = parseDependencies(dm[1] ?? "")
        }

        let window = WeekWindowParser.parse(title)

        var detailLines: [String] = []
        var lastDetailLine: Int?
        var children: [TaskItem] = []
        var i = headerIndex + 1
        while i < bodyEnd {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { i += 1; continue }
            if isSectionBoundary(line) { break }
            if trimmed.hasPrefix("|"), i + 1 < bodyEnd, isTableSeparator(lines[i + 1]),
               let table = parseTable(lines: lines, headerIndex: i) {
                children.append(contentsOf: tableChildren(from: table))
                i = min(table.endIndex, bodyEnd)
                continue
            }
            detailLines.append(trimmed)
            lastDetailLine = i
            i += 1
        }

        return TaskItem(
            id: id,
            title: title,
            status: status,
            priority: nil,
            dependencies: dependencies,
            window: window,
            description: nil,
            details: detailLines.isEmpty ? nil : detailLines.joined(separator: "\n"),
            testStrategy: [],
            children: children,
            statusLocation: statusLocation,
            detailsAppendLineIndex: lastDetailLine ?? headerIndex
        )
    }

    // MARK: - Tables (Task List summary + per-subtask breakdown tables)

    private struct ParsedTable {
        var columns: [String]
        var rows: [(lineIndex: Int, cells: [String])]
        var endIndex: Int
    }

    private static func isTableSeparator(_ line: String) -> Bool {
        let t = line.trimmingCharacters(in: .whitespaces)
        guard t.hasPrefix("|") else { return false }
        return t.allSatisfy { "|-: ".contains($0) }
    }

    private static func splitRow(_ line: String) -> [String] {
        var t = line.trimmingCharacters(in: .whitespaces)
        if t.hasPrefix("|") { t.removeFirst() }
        if t.hasSuffix("|") { t.removeLast() }
        return t.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private static func parseTable(lines: [String], headerIndex: Int) -> ParsedTable? {
        guard headerIndex + 1 < lines.count else { return nil }
        guard lines[headerIndex].trimmingCharacters(in: .whitespaces).hasPrefix("|") else { return nil }
        guard isTableSeparator(lines[headerIndex + 1]) else { return nil }
        let columns = splitRow(lines[headerIndex])
        var rows: [(Int, [String])] = []
        var i = headerIndex + 2
        while i < lines.count, lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("|") {
            rows.append((i, splitRow(lines[i])))
            i += 1
        }
        return ParsedTable(columns: columns, rows: rows, endIndex: i)
    }

    private static func tableChildren(from table: ParsedTable) -> [TaskItem] {
        guard let idCol = table.columns.firstIndex(where: { $0.uppercased().contains("ID") }) else { return [] }
        let statusCol = table.columns.firstIndex(where: { $0.uppercased().contains("STATUS") }) ?? (table.columns.count - 1)
        let titleCol = table.columns.indices.first { $0 != idCol && $0 != statusCol }

        return table.rows.compactMap { row -> TaskItem? in
            guard idCol < row.cells.count else { return nil }
            let rawId = row.cells[idCol].trimmingCharacters(in: CharacterSet(charactersIn: "` "))
            guard !rawId.isEmpty else { return nil }
            let title = (titleCol.flatMap { $0 < row.cells.count ? row.cells[$0] : nil } ?? rawId)
                .trimmingCharacters(in: CharacterSet(charactersIn: "` "))
            let statusRaw = statusCol < row.cells.count ? row.cells[statusCol] : "pending"
            let status = TaskStatus(rawValue: statusRaw.trimmingCharacters(in: .whitespaces).lowercased()) ?? .pending

            let extraDetails = table.columns.enumerated()
                .filter { $0.offset != idCol && $0.offset != statusCol && $0.offset != titleCol }
                .compactMap { offset, name -> String? in
                    guard offset < row.cells.count else { return nil }
                    let value = row.cells[offset]
                    guard !value.isEmpty, value != "—", value != "-" else { return nil }
                    return "\(name): \(value)"
                }
                .joined(separator: "\n")

            return TaskItem(
                id: rawId,
                title: title,
                status: status,
                priority: nil,
                dependencies: [],
                window: nil,
                description: nil,
                details: extraDetails.isEmpty ? nil : extraDetails,
                testStrategy: [],
                children: [],
                statusLocation: StatusLocation(lineIndex: row.lineIndex, kind: .tableRow, tableColumnIndex: statusCol),
                detailsAppendLineIndex: nil
            )
        }
    }

    // MARK: - Generic section capture

    private static func sectionKind(of line: String) -> String? {
        let t = line.trimmingCharacters(in: .whitespaces)
        if t.hasPrefix("**Description") { return "description" }
        if t.hasPrefix("**Details") { return "details" }
        if t.hasPrefix("**Test Strategy") { return "testStrategy" }
        if t == "### Subtasks" { return "subtasks" }
        return nil
    }

    private static func isSectionBoundary(_ line: String) -> Bool {
        if sectionKind(of: line) != nil { return true }
        let t = line.trimmingCharacters(in: .whitespaces)
        if t == "---" { return true }
        if t.hasPrefix("## ") || t.hasPrefix("### ") { return true }
        if isSubtaskHeader(line) { return true }
        return false
    }

    /// Collects non-blank lines from `start` until the next section boundary (or `end`).
    /// Returns the joined body, the index to resume scanning from, and the index of the
    /// last non-blank line collected (used as the write-back insertion point for new notes).
    private static func captureSection(lines: [String], start: Int, end: Int) -> (String, Int, Int?) {
        var i = start
        var collected: [String] = []
        var lastNonBlank: Int?
        while i < end {
            if isSectionBoundary(lines[i]) { break }
            let t = lines[i].trimmingCharacters(in: .whitespaces)
            if !t.isEmpty {
                collected.append(t)
                lastNonBlank = i
            }
            i += 1
        }
        return (collected.joined(separator: "\n"), i, lastNonBlank)
    }

    private static func captureChecklist(lines: [String], start: Int, end: Int) -> ([ChecklistItem], Int) {
        var i = start
        var items: [ChecklistItem] = []
        while i < end {
            if isSectionBoundary(lines[i]) { break }
            if let m = RegexUtil.firstMatch(in: lines[i], pattern: #"^-\s*\[([ xX])\]\s*(.*)$"#) {
                let checked = (m[1] ?? " ").lowercased() == "x"
                items.append(ChecklistItem(text: (m[2] ?? "").trimmingCharacters(in: .whitespaces), checked: checked, lineIndex: i))
            }
            i += 1
        }
        return (items, i)
    }

    // MARK: - Small shared helpers

    private static func parseDependencies(_ raw: String) -> [String] {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty || trimmed.lowercased() == "none" { return [] }
        return trimmed.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private static func lineValue(lines: [String], boldKey: String) -> String? {
        let pattern = "^\\*\\*\(NSRegularExpression.escapedPattern(for: boldKey))\\*\\*:\\s*(.*)$"
        let joined = lines.joined(separator: "\n")
        guard let match = RegexUtil.firstMatch(in: joined, pattern: pattern, options: [.anchorsMatchLines]) else {
            return nil
        }
        return match[1]?.trimmingCharacters(in: .whitespaces)
    }

    private static func inheritPriority(_ item: TaskItem, fallback: Priority?) -> TaskItem {
        var copy = item
        if copy.priority == nil { copy.priority = fallback }
        copy.children = copy.children.map { inheritPriority($0, fallback: copy.priority) }
        return copy
    }
}
