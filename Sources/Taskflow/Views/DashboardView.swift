import SwiftUI
import TaskflowCore

private enum DashboardScope: String, CaseIterable {
    case overview
    case today
    case upcoming
}

struct DashboardView: View {
    var store: TaskDocumentStore
    @Binding var selectedItemId: String?
    var onSelectPhase: (String) -> Void
    @State private var scope: DashboardScope = .overview

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.s8) {
                header

                if let document = store.document {
                    let schedule = ScheduleEngine.compute(document: document)

                    SegmentedScopeControl(
                        options: [(DashboardScope.overview, "All"), (.today, "Today"), (.upcoming, "Due Soon")],
                        selection: $scope
                    )

                    scopeCard(document: document, schedule: schedule)

                    if scope == .overview {
                        phaseTracks(schedule.phaseTracks, onSelectPhase: onSelectPhase)
                    }
                } else {
                    emptyState
                }
            }
            .padding(DesignTokens.Spacing.s8)
        }
        .background(DesignTokens.Colors.bg)
        .foregroundStyle(DesignTokens.Colors.text)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Taskflow")
                .font(DesignTokens.Typography.heading(22))
            Text(store.document?.sourceLabel ?? "tasks.md 기반 일정 대시보드")
                .font(.system(size: 12))
                .foregroundStyle(DesignTokens.Colors.neutral400)
        }
    }

    private var emptyState: some View {
        CardView {
            Text("아직 연결된 taskmaster .md 파일이 없습니다.")
                .font(.system(size: 14))
            Text("Sync 탭에서 파일을 추가하면 여기에 일정 현황이 표시됩니다.")
                .font(.system(size: 12))
                .foregroundStyle(DesignTokens.Colors.neutral400)
        }
    }

    @ViewBuilder
    private func scopeCard(document: TaskDocument, schedule: Schedule) -> some View {
        switch scope {
        case .overview:
            CardView(elevated: true) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Overall Progress")
                        .font(.system(size: 10, weight: .semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(DesignTokens.Colors.accent)
                    Spacer()
                    if let week = schedule.currentWeek {
                        Text("현재 W\(week)")
                            .font(.system(size: 11))
                            .foregroundStyle(DesignTokens.Colors.neutral400)
                    }
                }
                ProgressBarView(progress: Double(schedule.overall.pct))
                    .frame(height: 10)
                HStack {
                    Text("\(schedule.overall.doneCount)/\(schedule.overall.total) 완료")
                        .font(.system(size: 11))
                        .foregroundStyle(DesignTokens.Colors.neutral400)
                    Spacer()
                    if let delta = schedule.overallDelta {
                        TagView(delta.label, style: tagStyle(for: delta.tone))
                    }
                }
            }
        case .today:
            itemListCard(schedule.todayItems, emptyText: "오늘 시작할 항목이 없습니다.")
        case .upcoming:
            itemListCard(schedule.dueSoonItems, emptyText: "임박한 마감이 없습니다.")
        }
    }

    private func itemListCard(_ items: [ScheduleItem], emptyText: String) -> some View {
        CardView(elevated: true) {
            if items.isEmpty {
                Text(emptyText)
                    .font(.system(size: 13))
                    .foregroundStyle(DesignTokens.Colors.neutral400)
            } else {
                ForEach(items) { item in
                    Button {
                        onSelectPhase(item.phaseId)
                        selectedItemId = item.id
                    } label: {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(statusColor(item.status, locked: item.isLocked))
                                .frame(width: 9, height: 9)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.system(size: 14))
                                    .foregroundStyle(DesignTokens.Colors.text)
                                Text("\(item.sectionTitle) · \(item.window?.rawLabel ?? "")")
                                    .font(.system(size: 11))
                                    .foregroundStyle(DesignTokens.Colors.neutral400)
                            }
                            Spacer()
                            if item.isPulledForwardNextWeek {
                                TagView("예정", style: .outline)
                            }
                            if let priority = item.priority {
                                TagView(priority.displayLabel, style: item.isLocked ? .neutral : .accent2)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if item.id != items.last?.id {
                        Divider().background(DesignTokens.Colors.divider)
                    }
                }
            }
        }
    }

    private func phaseTracks(_ tracks: [PhaseTrack], onSelectPhase: @escaping (String) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(tracks) { track in
                Button {
                    onSelectPhase(track.id)
                } label: {
                    CardView {
                        HStack(alignment: .firstTextBaseline) {
                            Text(track.title)
                                .font(DesignTokens.Typography.heading(12))
                                .foregroundStyle(DesignTokens.Colors.neutral200)
                            Spacer()
                            TagView("\(track.stats.doneCount)/\(track.stats.total)", style: track.stats.pct >= 100 ? .accent : (track.stats.pct > 0 ? .outline : .neutral))
                        }
                        ProgressBarView(progress: Double(track.stats.pct), height: 4)
                        HStack {
                            if let due = track.dueDateLabel {
                                Text("Due \(due)")
                                    .font(.system(size: 10))
                                    .foregroundStyle(DesignTokens.Colors.neutral400)
                            }
                            Spacer()
                            if track.isActiveNow, let current = track.currentItemTitle {
                                Text("진행중 · \(current)")
                                    .font(.system(size: 10))
                                    .foregroundStyle(DesignTokens.Colors.accent300)
                                    .lineLimit(1)
                            }
                        }
                        HStack(spacing: 4) {
                            ForEach(track.chips) { chip in
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(chipColor(chip))
                                    .frame(width: 18, height: 18)
                            }
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func statusColor(_ status: TaskStatus, locked: Bool) -> Color {
        if locked { return DesignTokens.Colors.neutral700 }
        switch status {
        case .done: return DesignTokens.Colors.accent400
        case .inProgress: return DesignTokens.Colors.accent300
        default: return DesignTokens.Colors.neutral500
        }
    }

    private func chipColor(_ chip: Chip) -> Color {
        if chip.isDone { return DesignTokens.Colors.accent }
        if chip.isLocked { return DesignTokens.Colors.neutral900 }
        if chip.isCurrent { return DesignTokens.Colors.accent800 }
        return DesignTokens.Colors.neutral800
    }

    private func tagStyle(for tone: DeltaTone) -> TagStyle {
        switch tone {
        case .behind: return .accent
        case .ahead: return .outline
        case .onTrack: return .neutral
        }
    }
}
