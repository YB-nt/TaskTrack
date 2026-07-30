import Foundation

/// The parsed result of a taskmaster-format markdown file.
public struct TaskDocument: Codable, Equatable {
    public var projectName: String?
    public var sourceLabel: String?
    public var timelineRaw: String?
    /// Parsed from a "Week 1 = ..." style line in the document. Nil disables all
    /// week-relative scheduling features (locking, due-soon, planned-vs-actual delta) —
    /// ScheduleEngine degrades to plain progress percentages in that case.
    public var week1ReferenceDate: Date?
    public var tasks: [TaskItem]
    /// Full original file contents, kept so TaskFileWriter can apply targeted line edits
    /// without re-deriving the file from the parsed model (which would risk losing
    /// formatting/content the parser doesn't understand).
    public var rawText: String

    public init(
        projectName: String?,
        sourceLabel: String?,
        timelineRaw: String?,
        week1ReferenceDate: Date?,
        tasks: [TaskItem],
        rawText: String
    ) {
        self.projectName = projectName
        self.sourceLabel = sourceLabel
        self.timelineRaw = timelineRaw
        self.week1ReferenceDate = week1ReferenceDate
        self.tasks = tasks
        self.rawText = rawText
    }

    public var allItems: [TaskItem] {
        tasks.flatMap(\.flattened)
    }

    public func item(withId id: String) -> TaskItem? {
        allItems.first { $0.id == id }
    }

    /// Ancestor chain from the top-level task down to (and including) the item with `id`,
    /// or nil if no item has that id. Used to build breadcrumbs in the detail view.
    public func path(toId id: String) -> [TaskItem]? {
        func search(_ items: [TaskItem], trail: [TaskItem]) -> [TaskItem]? {
            for item in items {
                let newTrail = trail + [item]
                if item.id == id { return newTrail }
                if let found = search(item.children, trail: newTrail) { return found }
            }
            return nil
        }
        return search(tasks, trail: [])
    }
}
