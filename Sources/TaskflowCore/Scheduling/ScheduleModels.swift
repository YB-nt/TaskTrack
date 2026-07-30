import Foundation

public struct ProgressStats: Equatable {
    public var total: Int
    public var doneCount: Int
    public var pct: Int
}

public enum DeltaTone: Equatable {
    case behind
    case ahead
    case onTrack
}

public struct DeltaInfo: Equatable {
    public var label: String
    public var tone: DeltaTone
}

public struct Chip: Identifiable, Equatable {
    public var id: String
    public var isDone: Bool
    public var isCurrent: Bool
    public var isLocked: Bool
}

/// A leaf task item, decorated with the phase/section it belongs to, for display in
/// Dashboard's Today/Due Soon lists and Curriculum's grouped list.
public struct ScheduleItem: Identifiable, Equatable {
    public var id: String
    public var title: String
    public var status: TaskStatus
    public var priority: Priority?
    public var window: WeekWindow?
    public var phaseTitle: String
    public var sectionTitle: String
    public var isLocked: Bool
}

/// One top-level task ("Phase" in the dashboard), summarized for the overview track list.
public struct PhaseTrack: Identifiable, Equatable {
    public var id: String
    public var title: String
    public var stats: ProgressStats
    public var chips: [Chip]
    public var dueDateLabel: String?
    public var isActiveNow: Bool
    public var currentItemTitle: String?
}

/// Everything ScheduleEngine computes from a TaskDocument at a point in time.
/// `currentWeek` (and everything derived from it — locking, due-soon, delta) is nil
/// when the document has no parseable "Week 1 = ..." reference date; the dashboard
/// degrades to showing plain progress percentages in that case.
public struct Schedule: Equatable {
    public var overall: ProgressStats
    public var overallPlannedPct: Int?
    public var overallDelta: DeltaInfo?
    public var currentWeek: Int?
    public var phaseTracks: [PhaseTrack]
    public var todayItems: [ScheduleItem]
    public var dueSoonItems: [ScheduleItem]
}
