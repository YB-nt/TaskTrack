import SwiftUI

/// Ported from `nocturne.css` (the Claude Design export's design system). Colors, spacing,
/// and radii are copied exactly; Inter is not bundled (no font resource, no license file to
/// vendor for a v1 build), so Typography falls back to the system font at the same weights —
/// everything else in this file matches the source design 1:1.
public enum DesignTokens {
    public enum Colors {
        public static let bg = Color(hex: 0x120D0D)
        public static let surface = Color(hex: 0x1E1616)
        public static let text = Color(hex: 0xF5EFEC)
        public static let accent = Color(hex: 0xC81E2C)
        public static let divider = text.opacity(0.14)

        public static let neutral100 = Color(hex: 0xF6F1EE)
        public static let neutral200 = Color(hex: 0xE6DCD8)
        public static let neutral300 = Color(hex: 0xCCBFBA)
        public static let neutral400 = Color(hex: 0xAB9C96)
        public static let neutral500 = Color(hex: 0x8A7C77)
        public static let neutral600 = Color(hex: 0x6B5F5B)
        public static let neutral700 = Color(hex: 0x4D4341)
        public static let neutral800 = Color(hex: 0x302A29)
        public static let neutral900 = Color(hex: 0x1A1615)

        public static let accent100 = Color(hex: 0xFBE4E2)
        public static let accent200 = Color(hex: 0xF4C0BC)
        public static let accent300 = Color(hex: 0xE8938C)
        public static let accent400 = Color(hex: 0xD75F57)
        public static let accent800 = Color(hex: 0x560B10)
    }

    public enum Typography {
        public static func heading(_ size: CGFloat) -> Font { .system(size: size, weight: .medium) }
        public static func body(_ size: CGFloat = 15) -> Font { .system(size: size, weight: .regular) }
    }

    public enum Spacing {
        public static let s1: CGFloat = 2.8
        public static let s2: CGFloat = 5.6
        public static let s3: CGFloat = 8.4
        public static let s4: CGFloat = 11.2
        public static let s6: CGFloat = 16.8
        public static let s8: CGFloat = 22.4
    }

    public enum Radius {
        public static let sm: CGFloat = 4
        public static let md: CGFloat = 8
        public static let lg: CGFloat = 14
        public static let tag: CGFloat = 6 // calc(--radius-md * 0.75)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
