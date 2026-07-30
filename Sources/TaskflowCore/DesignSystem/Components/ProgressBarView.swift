import SwiftUI

/// Mirrors the inline progress bar markup used throughout the design (a rounded track
/// with a proportional accent fill) — used both for the big overview bar (height 10) and
/// the per-phase track bars (height 4).
public struct ProgressBarView: View {
    let progress: Double // 0...100
    var height: CGFloat
    var trackColor: Color
    var fillColor: Color

    public init(
        progress: Double,
        height: CGFloat = 10,
        trackColor: Color = DesignTokens.Colors.neutral800,
        fillColor: Color = DesignTokens.Colors.accent
    ) {
        self.progress = progress
        self.height = height
        self.trackColor = trackColor
        self.fillColor = fillColor
    }

    public var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(trackColor)
                Capsule()
                    .fill(fillColor)
                    .frame(width: geo.size.width * CGFloat(max(0, min(100, progress)) / 100))
            }
        }
        .frame(height: height)
    }
}
