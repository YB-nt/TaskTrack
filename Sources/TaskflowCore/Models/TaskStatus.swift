import Foundation

public enum TaskStatus: String, Codable, CaseIterable, Equatable {
    case pending
    case inProgress = "in-progress"
    case done
    case deferred
    case cancelled
    case blocked

    /// Progress credit used by ScheduleEngine's percentage math.
    public var credit: Double {
        switch self {
        case .done: return 1
        case .inProgress: return 0.5
        case .pending, .deferred, .cancelled, .blocked: return 0
        }
    }

    public var displayLabel: String {
        switch self {
        case .pending: return "대기"
        case .inProgress: return "진행중"
        case .done: return "완료"
        case .deferred: return "보류"
        case .cancelled: return "취소"
        case .blocked: return "차단"
        }
    }
}
