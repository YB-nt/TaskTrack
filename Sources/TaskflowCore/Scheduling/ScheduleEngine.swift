import Foundation

/// Ports the progress/lock/today/due-soon logic from the Claude Design prototype's
/// `support.js` (PHASES_RAW → chapters → steps) to work over real dates instead of the
/// prototype's hardcoded `CURRENT_WEEK = 5` demo data.
///
/// Terminology mapping: a top-level `TaskItem` is a "Phase". Its direct children are
/// "Sections" (the prototype's "chapters"/weeks). A section's leaves are its actionable
/// "steps". A task with no children is its own single-step section — this is what makes
/// the engine work unmodified whether the document is 2 levels deep (`tasks.md`) or 3
/// (`tasks_v2.md`).
public enum ScheduleEngine {
    public static func compute(document: TaskDocument, now: Date = Date(), dueSoonWindowDays: Int = 3) -> Schedule {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current

        let currentWeek: Int? = document.week1ReferenceDate.map { weekNumber(for: now, week1: $0, calendar: calendar) }
        let phases = document.tasks.map(Phase.init)

        let allLeaves = phases.flatMap(\.leaves)
        let overall = stats(allLeaves)

        var overallPlannedPct: Int?
        var overallDelta: DeltaInfo?
        if let currentWeek {
            let starts = allLeaves.compactMap { $0.window?.startWeek }
            let ends = allLeaves.compactMap { $0.window?.endWeek }
            if let minStart = starts.min(), let maxEnd = ends.max(), maxEnd > minStart {
                let planned = weekProgress(start: minStart, end: maxEnd, current: currentWeek)
                overallPlannedPct = planned
                overallDelta = delta(actual: overall.pct, planned: planned)
            }
        }

        var todayItems: [ScheduleItem] = []
        var dueSoonItems: [ScheduleItem] = []

        if let currentWeek {
            let isAheadOfSchedule = overallDelta?.tone == .ahead
            for phase in phases {
                // 계획보다 앞서가는 중이고 이 Phase가 이미 시작된 상태라면(문제 하나라도
                // done/in-progress), 아직 주차가 안 된 섹션 중 "가장 가까운, 아직 안 끝난"
                // 딱 하나만 오늘 할 일로 당겨온다 — Phase 전체 남은 주차를 다 쏟아내지 않고
                // "다음 문제"만 보여주기 위함. 섹션의 "끝났음" 판정은 체크포인트/총정리 같은
                // 부가 항목이 아니라 실제 "문제 X-Y" 항목 기준으로 본다 — 체크포인트 메모가
                // 안 끝났다고 다음 문제가 안 보이면 안 되므로.
                let phaseHasStartedWork = phase.leaves.contains { $0.status == .done || $0.status == .inProgress }
                let nearestUnclearedFutureWeek: Int? = (isAheadOfSchedule && phaseHasStartedWork)
                    ? phase.sections
                        .filter { !isClearedForProgression($0) }
                        .compactMap { section -> Int? in
                            guard let leaf = section.leaves.first(where: { $0.status != .done }) else { return nil }
                            guard let startWeek = leaf.window?.startWeek, startWeek > currentWeek else { return nil }
                            return startWeek
                        }
                        .min()
                    : nil

                for section in phase.sections {
                    guard let next = section.leaves.first(where: { $0.status != .done }) else { continue }
                    guard let startWeek = next.window?.startWeek else { continue }
                    let isCurrentWeek = startWeek <= currentWeek
                    let isPulledForward = nearestUnclearedFutureWeek == startWeek
                    guard isCurrentWeek || isPulledForward else { continue }
                    todayItems.append(scheduleItem(next, phase: phase, section: section, currentWeek: currentWeek, isPulledForwardNextWeek: isPulledForward))
                }
            }
            // 지금 진행중인 항목을 최우선으로 올리고, 그 다음은 기존처럼 priority 가중치로 정렬한다.
            todayItems.sort { lhs, rhs in
                let lhsInProgress = lhs.status == .inProgress
                let rhsInProgress = rhs.status == .inProgress
                if lhsInProgress != rhsInProgress { return lhsInProgress }
                return (lhs.priority?.weight ?? 0) > (rhs.priority?.weight ?? 0)
            }

            if let week1 = document.week1ReferenceDate {
                for phase in phases {
                    for section in phase.sections {
                        for item in section.leaves where item.status != .done {
                            guard let end = item.window?.endWeek else { continue }
                            let dueDate = weekEndDate(end, week1: week1, calendar: calendar)
                            let diffDays = calendar.dateComponents([.day], from: now, to: dueDate).day ?? Int.max
                            guard diffDays <= dueSoonWindowDays else { continue }
                            dueSoonItems.append(scheduleItem(item, phase: phase, section: section, currentWeek: currentWeek))
                        }
                    }
                }
                dueSoonItems.sort { lhs, rhs in
                    let lhsEnd = lhs.window?.endWeek ?? Int.max
                    let rhsEnd = rhs.window?.endWeek ?? Int.max
                    if lhsEnd != rhsEnd { return lhsEnd < rhsEnd }
                    return (lhs.priority?.weight ?? 0) > (rhs.priority?.weight ?? 0)
                }
            }
        }

        let phaseTracks = buildPhaseTracks(phases: phases, currentWeek: currentWeek, week1: document.week1ReferenceDate, calendar: calendar)

        return Schedule(
            overall: overall,
            overallPlannedPct: overallPlannedPct,
            overallDelta: overallDelta,
            currentWeek: currentWeek,
            phaseTracks: phaseTracks,
            todayItems: todayItems,
            dueSoonItems: dueSoonItems
        )
    }

    // MARK: - Phase/Section grouping

    private struct Section {
        let title: String
        let leaves: [TaskItem]
        var allDone: Bool { !leaves.isEmpty && leaves.allSatisfy { $0.status == .done } }
    }

    /// A section counts as "cleared" once every actual `문제 X-Y` item in it is done — a
    /// trailing checkpoint/summary item left open doesn't hold up progression to the next
    /// section for the ahead-of-schedule pull-forward. Sections with no `문제`-tagged leaves
    /// at all (pure checklist sections) fall back to plain `allDone`.
    private static func isClearedForProgression(_ section: Section) -> Bool {
        let problemLeaves = section.leaves.filter { ProblemDetailParser.problemId(in: $0.title) != nil }
        if !problemLeaves.isEmpty {
            return problemLeaves.allSatisfy { $0.status == .done }
        }
        return section.allDone
    }

    private struct Phase {
        let task: TaskItem
        let sections: [Section]

        init(_ task: TaskItem) {
            self.task = task
            if task.children.isEmpty {
                sections = [Section(title: task.title, leaves: [task])]
            } else {
                sections = task.children.map { Section(title: $0.title, leaves: $0.leaves) }
            }
        }

        var leaves: [TaskItem] { sections.flatMap(\.leaves) }

        func isLocked(_ item: TaskItem, currentWeek: Int?) -> Bool {
            guard let currentWeek, let window = item.window, window.startWeek > currentWeek else { return false }
            guard let sectionIndex = sections.firstIndex(where: { section in section.leaves.contains { $0.id == item.id } }) else {
                return false
            }
            guard sectionIndex > 0 else { return false }
            return !sections[sectionIndex - 1].allDone
        }
    }

    private static func scheduleItem(
        _ item: TaskItem, phase: Phase, section: Section, currentWeek: Int?,
        isPulledForwardNextWeek: Bool = false
    ) -> ScheduleItem {
        ScheduleItem(
            id: item.id,
            title: item.title,
            status: item.status,
            priority: item.priority,
            window: item.window,
            phaseId: phase.task.id,
            phaseTitle: phase.task.title,
            sectionTitle: section.title,
            isLocked: phase.isLocked(item, currentWeek: currentWeek),
            isPulledForwardNextWeek: isPulledForwardNextWeek
        )
    }

    private static func buildPhaseTracks(phases: [Phase], currentWeek: Int?, week1: Date?, calendar: Calendar) -> [PhaseTrack] {
        struct Sortable { let track: PhaseTrack; let urgencyWeek: Int; let index: Int }

        let sortable: [Sortable] = phases.enumerated().map { index, phase in
            let leaves = phase.leaves
            let phaseStats = stats(leaves)
            let chips = leaves.map { leaf in
                Chip(id: leaf.id, isDone: leaf.status == .done, isCurrent: leaf.status == .inProgress, isLocked: phase.isLocked(leaf, currentWeek: currentWeek))
            }
            let openLeaves = leaves.filter { $0.status != .done }
            let isActiveNow = currentWeek.map { cw in openLeaves.contains { ($0.window?.startWeek ?? Int.max) <= cw } } ?? false
            let urgencyWeek = openLeaves.compactMap { $0.window?.endWeek }.min()
                ?? leaves.compactMap { $0.window?.endWeek }.min()
                ?? Int.max
            let dueDateLabel: String? = week1.flatMap { week1 in
                leaves.compactMap { $0.window?.endWeek }.max().map { formatWeekEndDate($0, week1: week1, calendar: calendar) }
            }
            let track = PhaseTrack(
                id: phase.task.id,
                title: phase.task.title,
                stats: phaseStats,
                chips: chips,
                dueDateLabel: dueDateLabel,
                isActiveNow: isActiveNow,
                currentItemTitle: leaves.first { $0.status == .inProgress }?.title
            )
            return Sortable(track: track, urgencyWeek: urgencyWeek, index: index)
        }

        return sortable.sorted { a, b in
            if a.track.isActiveNow != b.track.isActiveNow { return a.track.isActiveNow && !b.track.isActiveNow }
            if a.urgencyWeek != b.urgencyWeek { return a.urgencyWeek < b.urgencyWeek }
            return a.index < b.index
        }.map(\.track)
    }

    // MARK: - Math helpers

    private static func stats(_ items: [TaskItem]) -> ProgressStats {
        let total = items.count
        guard total > 0 else { return ProgressStats(total: 0, doneCount: 0, pct: 0) }
        let creditSum = items.reduce(0.0) { $0 + $1.status.credit }
        let doneCount = items.filter { $0.status == .done }.count
        let pct = Int((creditSum / Double(total) * 100).rounded())
        return ProgressStats(total: total, doneCount: doneCount, pct: pct)
    }

    private static func weekProgress(start: Int, end: Int, current: Int) -> Int {
        if current <= start { return 0 }
        if current >= end { return 100 }
        return Int((Double(current - start) / Double(end - start) * 100).rounded())
    }

    private static func delta(actual: Int, planned: Int) -> DeltaInfo {
        let diff = actual - planned
        if diff <= -8 { return DeltaInfo(label: "일정보다 \(abs(diff))%p 뒤처짐", tone: .behind) }
        if diff >= 8 { return DeltaInfo(label: "일정보다 \(diff)%p 앞섬", tone: .ahead) }
        return DeltaInfo(label: "계획대로 진행중", tone: .onTrack)
    }

    private static func weekNumber(for date: Date, week1: Date, calendar: Calendar) -> Int {
        let days = calendar.dateComponents([.day], from: week1, to: date).day ?? 0
        return Int(floor(Double(days) / 7.0)) + 1
    }

    private static func weekEndDate(_ week: Int, week1: Date, calendar: Calendar) -> Date {
        calendar.date(byAdding: .day, value: (week - 1) * 7 + 6, to: week1) ?? week1
    }

    private static func formatWeekEndDate(_ week: Int, week1: Date, calendar: Calendar) -> String {
        let date = weekEndDate(week, week1: week1, calendar: calendar)
        let comps = calendar.dateComponents([.month, .day], from: date)
        return "\(comps.month ?? 0)월 \(comps.day ?? 0)일"
    }
}
