import Foundation

/// One `- [ ]` / `- [x]` line from a task's Test Strategy section.
/// `lineIndex` is preserved so TaskFileWriter can flip the checkbox in place.
public struct ChecklistItem: Codable, Equatable, Identifiable {
    public var text: String
    public var checked: Bool
    public var lineIndex: Int

    public init(text: String, checked: Bool, lineIndex: Int) {
        self.text = text
        self.checked = checked
        self.lineIndex = lineIndex
    }

    public var id: Int { lineIndex }
}
