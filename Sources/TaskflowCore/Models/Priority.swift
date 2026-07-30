import Foundation

public enum Priority: String, Codable, CaseIterable, Equatable {
    case high
    case medium
    case low

    public var displayLabel: String {
        switch self {
        case .high: return "높음"
        case .medium: return "중간"
        case .low: return "낮음"
        }
    }

    /// Higher weight sorts first when ordering same-status items (mirrors support.js PRIORITY_WEIGHT).
    public var weight: Int {
        switch self {
        case .high: return 2
        case .medium: return 1
        case .low: return 0
        }
    }
}
