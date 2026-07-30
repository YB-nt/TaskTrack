import SwiftUI

/// Mirrors nocturne.css's `.card` (+ `.elev-sm`) class.
public struct CardView<Content: View>: View {
    let elevated: Bool
    let content: Content

    public init(elevated: Bool = false, @ViewBuilder content: () -> Content) {
        self.elevated = elevated
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.s2) {
            content
        }
        .padding(DesignTokens.Spacing.s3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignTokens.Colors.surface)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                .stroke(elevated ? DesignTokens.Colors.neutral800 : .clear, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
    }
}
