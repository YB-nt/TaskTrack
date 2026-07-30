import AppKit
import UniformTypeIdentifiers

enum FilePicker {
    @MainActor
    static func pickMarkdownFile() -> URL? {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.title = "Taskmaster .md 파일 선택"
        if let markdownType = UTType(filenameExtension: "md") {
            panel.allowedContentTypes = [markdownType, .plainText]
        } else {
            panel.allowedContentTypes = [.plainText]
        }
        return panel.runModal() == .OK ? panel.url : nil
    }
}
