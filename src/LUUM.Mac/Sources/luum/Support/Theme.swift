import SwiftUI

enum LuumTheme {
    static let accent = Color(red: 0.70, green: 0.49, blue: 0.98)
    static let secondaryAccent = Color(red: 0.42, green: 0.24, blue: 0.82)
    static let electricBlue = Color(red: 0.82, green: 0.76, blue: 1.0)
    static let hotPink = Color(red: 0.58, green: 0.31, blue: 0.88)
    static let baseBlack = Color(red: 0.03, green: 0.03, blue: 0.05)
    static let elevatedBlack = Color(red: 0.08, green: 0.07, blue: 0.11)
    static let panelFill = Color.white.opacity(0.028)
    static let panelFillStrong = Color.white.opacity(0.045)
    static let surfaceOutline = Color.white.opacity(0.085)
    static let surfaceInnerHighlight = Color.white.opacity(0.06)
    static let textSecondary = Color.white.opacity(0.72)
    static let textMuted = Color.white.opacity(0.48)
    static let pageGradient = LinearGradient(
        colors: [
            baseBlack,
            Color(red: 0.04, green: 0.03, blue: 0.08),
            Color(red: 0.08, green: 0.05, blue: 0.14),
            Color(red: 0.12, green: 0.06, blue: 0.20),
            Color(red: 0.02, green: 0.02, blue: 0.04),
        ],
        startPoint: .top,
        endPoint: .bottomTrailing
    )
}

extension ActivityCategory {
    var tint: Color {
        switch colorToken {
        case .sky:
            Color(red: 0.48, green: 0.78, blue: 1.0)
        case .magenta:
            Color(red: 0.92, green: 0.38, blue: 0.82)
        case .mint:
            Color(red: 0.56, green: 0.87, blue: 0.78)
        case .amber:
            Color(red: 1.0, green: 0.79, blue: 0.38)
        case .silver:
            Color(red: 0.74, green: 0.74, blue: 0.88)
        case .violet:
            LuumTheme.secondaryAccent
        case .coral:
            Color(red: 1.0, green: 0.48, blue: 0.43)
        case .teal:
            Color(red: 0.28, green: 0.83, blue: 0.79)
        }
    }

    var glassTint: Color {
        tint.opacity(0.35)
    }
}
