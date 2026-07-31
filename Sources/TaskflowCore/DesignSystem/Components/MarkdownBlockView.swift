import SwiftUI

/// Minimal block-level renderer for the `**Details**` / 하위 파일 write-ups, which use bold
/// labels, fenced code blocks, and `- ` bullet lists but nothing fancier. `Text(LocalizedStringKey:)`
/// already renders inline markdown (`**bold**`, `` `code` ``, `*italic*`) — this only adds the
/// block-level pieces it doesn't: code fences and bullet lists.
public struct MarkdownBlockView: View {
    private let text: String

    public init(_ text: String) {
        self.text = text
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.s3) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                render(block)
            }
        }
    }

    @ViewBuilder
    private func render(_ block: Block) -> some View {
        switch block {
        case .code(let language, let code):
            VStack(alignment: .leading, spacing: 4) {
                if let language {
                    Text(language.uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(DesignTokens.Colors.neutral400)
                }
                Text(code)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(DesignTokens.Colors.text)
                    .textSelection(.enabled)
            }
            .padding(DesignTokens.Spacing.s3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DesignTokens.Colors.neutral900)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm))

        case .bulletList(let items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .top, spacing: 6) {
                        Text("•").foregroundStyle(DesignTokens.Colors.neutral400)
                        Text(LocalizedStringKey(item))
                    }
                }
            }

        case .paragraph(let text):
            Text(LocalizedStringKey(text))
        }
    }

    private enum Block {
        case paragraph(String)
        case bulletList([String])
        case code(language: String?, code: String)
    }

    private var blocks: [Block] {
        let lines = text.components(separatedBy: "\n")
        var result: [Block] = []
        var i = 0
        while i < lines.count {
            let trimmed = lines[i].trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                i += 1
                continue
            }

            if trimmed.hasPrefix("```") {
                let language = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                i += 1
                var code: [String] = []
                while i < lines.count, !lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    code.append(lines[i])
                    i += 1
                }
                i += 1 // skip closing fence, if any
                result.append(.code(language: language.isEmpty ? nil : language, code: code.joined(separator: "\n")))
                continue
            }

            if isBulletLine(trimmed) {
                var items: [String] = []
                while i < lines.count, isBulletLine(lines[i].trimmingCharacters(in: .whitespaces)) {
                    items.append(String(lines[i].trimmingCharacters(in: .whitespaces).dropFirst(2)))
                    i += 1
                }
                result.append(.bulletList(items))
                continue
            }

            var paragraphLines: [String] = []
            while i < lines.count {
                let t = lines[i].trimmingCharacters(in: .whitespaces)
                if t.isEmpty || t.hasPrefix("```") || isBulletLine(t) { break }
                paragraphLines.append(t)
                i += 1
            }
            result.append(.paragraph(paragraphLines.joined(separator: "\n")))
        }
        return result
    }

    private func isBulletLine(_ trimmed: String) -> Bool {
        trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ")
    }
}
