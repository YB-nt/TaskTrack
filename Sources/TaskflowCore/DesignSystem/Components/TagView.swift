import SwiftUI

/// Mirrors nocturne.css's `.tag` variants (`.tag-accent`, `.tag-accent-2`, `.tag-neutral`, `.tag-outline`).
public enum TagStyle {
    case accent
    case accent2
    case neutral
    case outline
}

public struct TagView: View {
    let text: String
    let style: TagStyle

    public init(_ text: String, style: TagStyle = .neutral) {
        self.text = text
        self.style = style
    }

    public var body: some View {
        Text(text)
            .font(.system(size: 11))
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .foregroundStyle(foreground)
            .background(background)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.tag)
                    .stroke(style == .outline ? DesignTokens.Colors.accent : .clear, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.tag))
    }

    private var background: Color {
        switch style {
        case .accent, .accent2: return DesignTokens.Colors.accent800
        case .neutral: return DesignTokens.Colors.neutral800
        case .outline: return .clear
        }
    }

    private var foreground: Color {
        switch style {
        case .accent, .accent2: return DesignTokens.Colors.accent100
        case .neutral: return DesignTokens.Colors.neutral100
        case .outline: return DesignTokens.Colors.accent
        }
    }
}
