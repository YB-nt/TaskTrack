import Foundation

/// A schedule window expressed in week numbers relative to the document's week-1 reference date.
/// `startWeek`/`endWeek` are inclusive. Open-ended windows ("W17+") set endWeek == startWeek.
public struct WeekWindow: Codable, Equatable {
    public var startWeek: Int
    public var endWeek: Int
    public var rawLabel: String

    public init(startWeek: Int, endWeek: Int, rawLabel: String) {
        self.startWeek = startWeek
        self.endWeek = endWeek
        self.rawLabel = rawLabel
    }

    public var isSingleWeek: Bool { startWeek == endWeek }
}
