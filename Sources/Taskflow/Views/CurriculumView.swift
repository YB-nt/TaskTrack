import SwiftUI
import TaskflowCore

private enum StatusFilter: String, CaseIterable {
    case all = "All"
    case pending = "Pending"
    case active = "Active"
    case done = "Done"

    func matches(_ status: TaskStatus) -> Bool {
        switch self {
        case .all: return true
        case .pending: return status == .pending
        case .active: return status == .inProgress
        case .done: return status == .done
        }
    }
}

struct CurriculumView: View {
    var store: TaskDocumentStore
    @Binding var selectedItemId: String?
    @Binding var scrollToPhaseId: String?
    @State private var filter: StatusFilter = .all
    @State private var searchText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.s6) {
            Text("Curriculum")
                .font(DesignTokens.Typography.heading(20))

            if store.document != nil {
                SegmentedScopeControl(
                    options: StatusFilter.allCases.map { ($0, $0.rawValue) },
                    selection: $filter
                )
                TextField("Search steps", text: $searchText)
                    .textFieldStyle(.plain)
                    .padding(8)
                    .background(DesignTokens.Colors.surface)
                    .overlay(RoundedRectangle(cornerRadius: DesignTokens.Radius.md).stroke(DesignTokens.Colors.divider, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md))

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 20) {
                            ForEach(store.document!.tasks) { phase in
                                phaseSection(phase)
                                    .id(phase.id)
                            }
                        }
                    }
                    // Dashboard에서 처음 Curriculum으로 전환되는 경우 이 뷰 자체가 새로
                    // 생성되므로 onChange는 초기값에 반응하지 않는다 — onAppear로도 잡는다.
                    .onAppear { jumpToPendingPhase(using: proxy) }
                    .onChange(of: scrollToPhaseId) { _, _ in jumpToPendingPhase(using: proxy) }
                }
            } else {
                CardView {
                    Text("Sync 탭에서 taskmaster .md 파일을 추가하면 여기에 커리큘럼이 표시됩니다.")
                        .font(.system(size: 13))
                        .foregroundStyle(DesignTokens.Colors.neutral400)
                }
            }
        }
        .padding(DesignTokens.Spacing.s8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(DesignTokens.Colors.bg)
        .foregroundStyle(DesignTokens.Colors.text)
    }

    @ViewBuilder
    private func phaseSection(_ phase: TaskItem) -> some View {
        let steps = filteredSteps(phase.leaves)
        if !steps.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(phase.title)
                        .font(DesignTokens.Typography.heading(15))
                        .foregroundStyle(DesignTokens.Colors.neutral300)
                    Spacer()
                    Text("\(phase.window?.rawLabel ?? "")")
                        .font(.system(size: 11))
                        .foregroundStyle(DesignTokens.Colors.neutral400)
                }
                VStack(spacing: 0) {
                    ForEach(steps) { step in
                        Button {
                            selectedItemId = step.id
                        } label: {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(step.status == .done ? DesignTokens.Colors.accent400 : (step.status == .inProgress ? DesignTokens.Colors.accent300 : DesignTokens.Colors.neutral500))
                                    .frame(width: 9, height: 9)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(step.title).font(.system(size: 14)).foregroundStyle(DesignTokens.Colors.text)
                                    Text(step.window?.rawLabel ?? "").font(.system(size: 11)).foregroundStyle(DesignTokens.Colors.neutral400)
                                }
                                Spacer()
                                if let priority = step.priority {
                                    TagView(priority.displayLabel, style: .accent2)
                                }
                            }
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if step.id != steps.last?.id {
                            Divider().background(DesignTokens.Colors.divider)
                        }
                    }
                }
            }
        }
    }

    private func jumpToPendingPhase(using proxy: ScrollViewProxy) {
        guard let phaseId = scrollToPhaseId else { return }
        filter = .all
        searchText = ""
        // 필터 리셋으로 숨겨져 있던 섹션이 다시 렌더링된 뒤 스크롤해야 하므로 한 틱 미룬다.
        DispatchQueue.main.async {
            withAnimation {
                proxy.scrollTo(phaseId, anchor: .top)
            }
        }
        scrollToPhaseId = nil
    }

    private func filteredSteps(_ leaves: [TaskItem]) -> [TaskItem] {
        leaves.filter { item in
            filter.matches(item.status) &&
            (searchText.isEmpty || item.title.localizedCaseInsensitiveContains(searchText))
        }
        // 지금 진행중인(in-progress) 항목을 목록 상단으로 올린다 — 나머지는 원래(문서) 순서 유지.
        .sorted { lhs, rhs in
            (lhs.status == .inProgress ? 0 : 1) < (rhs.status == .inProgress ? 0 : 1)
        }
    }
}
