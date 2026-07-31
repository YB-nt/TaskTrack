import SwiftUI
import TaskflowCore

struct StepDetailView: View {
    let item: TaskItem
    var store: TaskDocumentStore
    @Environment(\.dismiss) private var dismiss
    @State private var noteText: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header

                if let breadcrumb {
                    Text(breadcrumb)
                        .font(.system(size: 10, weight: .semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(DesignTokens.Colors.accent)
                }

                Text(currentItem.title)
                    .font(DesignTokens.Typography.heading(20))

                HStack(spacing: 8) {
                    TagView(currentItem.status.displayLabel, style: statusTagStyle)
                    if let priority = currentItem.priority {
                        TagView("Priority: \(priority.displayLabel)", style: .accent2)
                    }
                    if let window = currentItem.window {
                        TagView(window.rawLabel, style: .outline)
                    }
                }

                if let description = currentItem.description {
                    MarkdownBlockView(description)
                        .font(.system(size: 14))
                        .foregroundStyle(DesignTokens.Colors.text.opacity(0.85))
                }

                if let details = currentItem.details {
                    section("Details") {
                        MarkdownBlockView(details)
                            .font(.system(size: 13))
                            .foregroundStyle(DesignTokens.Colors.text.opacity(0.85))
                    }
                }

                if let supplementDetail {
                    section("실행 문서 (하위 파일)") {
                        MarkdownBlockView(supplementDetail)
                            .font(.system(size: 13))
                            .foregroundStyle(DesignTokens.Colors.text.opacity(0.85))
                    }
                }

                if !currentItem.dependencies.isEmpty {
                    section("Prerequisites") {
                        FlowTagsView(items: currentItem.dependencies) { depId in
                            store.document?.item(withId: depId)?.title ?? depId
                        }
                    }
                }

                if !currentItem.testStrategy.isEmpty {
                    section("Checklist") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(currentItem.testStrategy) { checkItem in
                                Button {
                                    store.toggleChecklistItem(checkItem)
                                } label: {
                                    HStack(alignment: .top, spacing: 8) {
                                        Image(systemName: checkItem.checked ? "checkmark.square.fill" : "square")
                                            .foregroundStyle(checkItem.checked ? DesignTokens.Colors.accent : DesignTokens.Colors.neutral600)
                                        Text(checkItem.text)
                                            .font(.system(size: 13))
                                            .foregroundStyle(DesignTokens.Colors.text)
                                            .strikethrough(checkItem.checked)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                section("메모 추가") {
                    HStack {
                        TextField("이 항목에 진행 상황 메모를 추가", text: $noteText)
                            .textFieldStyle(.plain)
                            .padding(8)
                            .background(DesignTokens.Colors.surface)
                            .overlay(RoundedRectangle(cornerRadius: DesignTokens.Radius.md).stroke(DesignTokens.Colors.divider, lineWidth: 1))
                            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
                        Button("추가") {
                            guard !noteText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                            store.appendDetailNote(noteText, to: currentItem)
                            noteText = ""
                        }
                        .buttonStyle(.taskflowSecondary)
                        .fixedSize()
                    }
                }

                HStack(spacing: 10) {
                    Button("Edit") {}
                        .buttonStyle(.taskflowSecondary)
                    Button("Mark Complete") {
                        store.setStatus(.done, for: currentItem)
                    }
                    .buttonStyle(.taskflowPrimary)
                    .disabled(currentItem.status == .done)
                }
                .padding(.top, 6)
            }
            .padding(20)
        }
        .background(DesignTokens.Colors.bg)
        .foregroundStyle(DesignTokens.Colors.text)
    }

    /// Re-reads the item from the live document (rather than the possibly-stale `item`
    /// passed in at sheet-presentation time) so toggles/notes reflect immediately.
    private var currentItem: TaskItem {
        store.document?.item(withId: item.id) ?? item
    }

    private var supplementDetail: String? {
        guard let problemId = ProblemDetailParser.problemId(in: currentItem.title) else { return nil }
        return store.supplementDetail(for: problemId)
    }

    private var breadcrumb: String? {
        guard let path = store.document?.path(toId: item.id), path.count > 1 else { return nil }
        return path.dropLast().map(\.title).joined(separator: " · ")
    }

    private var statusTagStyle: TagStyle {
        switch currentItem.status {
        case .done: return .accent
        case .inProgress: return .outline
        default: return .neutral
        }
    }

    private var header: some View {
        HStack {
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(DesignTokens.Colors.neutral500)
            }
            .buttonStyle(.plain)
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(DesignTokens.Typography.heading(12))
                .foregroundStyle(DesignTokens.Colors.neutral400)
            content()
        }
    }
}

/// Simple wrapping tag row (dependency chips don't need precise CSS flex-wrap fidelity,
/// just to not clip on narrow sheet widths).
private struct FlowTagsView: View {
    let items: [String]
    let label: (String) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { id in
                        TagView(label(id), style: .outline)
                    }
                }
            }
        }
    }

    private var rows: [[String]] {
        items.chunked(into: 3)
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map { Array(self[$0..<Swift.min($0 + size, count)]) }
    }
}
