import Foundation

/// How a task's status token is spelled out in the source file, so TaskFileWriter can
/// rewrite just that one line with a targeted regex instead of doing column arithmetic
/// (which breaks on multi-byte Korean text).
public enum StatusFieldKind: String, Codable, Equatable {
    /// `# Status: pending` inside a fenced code block.
    case fencedField
    /// `**1.2 — Week 5: ...** \`pending\` / deps: ...`
    case inlineBacktickAfterBold
    /// A markdown table row whose last cell is the status.
    case tableRow
}

public struct StatusLocation: Codable, Equatable {
    public var lineIndex: Int
    public var kind: StatusFieldKind
    /// Cell index within the row, only set (and only meaningful) when `kind == .tableRow`.
    public var tableColumnIndex: Int?

    public init(lineIndex: Int, kind: StatusFieldKind, tableColumnIndex: Int? = nil) {
        self.lineIndex = lineIndex
        self.kind = kind
        self.tableColumnIndex = tableColumnIndex
    }
}

/// A task or subtask, recursively. Depth is not fixed — `tasks.md` samples go two levels deep
/// (Task → Subtask), `tasks_v2.md` goes three (Task → Subtask → per-subtask table row), and
/// nothing here assumes a maximum depth since the source format itself doesn't guarantee one.
public struct TaskItem: Codable, Identifiable, Equatable {
    public var id: String
    public var title: String
    public var status: TaskStatus
    public var priority: Priority?
    public var dependencies: [String]
    public var window: WeekWindow?
    public var description: String?
    public var details: String?
    public var testStrategy: [ChecklistItem]
    public var children: [TaskItem]

    // Write-back metadata. Absent when the field wasn't found in a recognizable form
    // (write actions for that field are simply disabled in the UI in that case).
    public var statusLocation: StatusLocation?
    /// Line index of the last non-empty line inside this task's **Details** section,
    /// i.e. where a new timestamped note gets appended. Nil if there's no Details section.
    public var detailsAppendLineIndex: Int?

    public init(
        id: String,
        title: String,
        status: TaskStatus,
        priority: Priority?,
        dependencies: [String],
        window: WeekWindow?,
        description: String?,
        details: String?,
        testStrategy: [ChecklistItem],
        children: [TaskItem],
        statusLocation: StatusLocation?,
        detailsAppendLineIndex: Int?
    ) {
        self.id = id
        self.title = title
        self.status = status
        self.priority = priority
        self.dependencies = dependencies
        self.window = window
        self.description = description
        self.details = details
        self.testStrategy = testStrategy
        self.children = children
        self.statusLocation = statusLocation
        self.detailsAppendLineIndex = detailsAppendLineIndex
    }

    /// All leaf nodes (no children) under this item, depth-first, in document order.
    public var leaves: [TaskItem] {
        children.isEmpty ? [self] : children.flatMap(\.leaves)
    }

    /// This item and every descendant, depth-first, in document order.
    public var flattened: [TaskItem] {
        [self] + children.flatMap(\.flattened)
    }
}
