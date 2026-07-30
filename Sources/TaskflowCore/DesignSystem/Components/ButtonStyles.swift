import SwiftUI

/// Mirrors nocturne.css's `.btn-primary` (accent outline + text).
public struct PrimaryButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(DesignTokens.Colors.accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(configuration.isPressed ? DesignTokens.Colors.accent.opacity(0.22) : DesignTokens.Colors.accent.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                    .stroke(DesignTokens.Colors.accent, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
    }
}

/// Mirrors nocturne.css's `.btn-secondary` (divider-colored outline).
public struct SecondaryButtonStyle: ButtonStyle {
    let selected: Bool
    public init(selected: Bool = false) {
        self.selected = selected
    }
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(selected ? .white : DesignTokens.Colors.text)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(selected ? DesignTokens.Colors.accent : (configuration.isPressed ? DesignTokens.Colors.text.opacity(0.14) : Color.clear))
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                    .stroke(selected ? DesignTokens.Colors.accent : DesignTokens.Colors.divider, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
    }
}

public extension ButtonStyle where Self == PrimaryButtonStyle {
    static var taskflowPrimary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

public extension ButtonStyle where Self == SecondaryButtonStyle {
    static var taskflowSecondary: SecondaryButtonStyle { SecondaryButtonStyle() }
    static func taskflowSecondary(selected: Bool) -> SecondaryButtonStyle { SecondaryButtonStyle(selected: selected) }
}
