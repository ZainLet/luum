import SwiftUI

enum LuumTheme {
    static let accent = Color(red: 0.48, green: 0.34, blue: 0.86)
    static let secondaryAccent = Color(red: 0.35, green: 0.30, blue: 0.56)
    static let electricBlue = Color(red: 0.62, green: 0.53, blue: 0.95)
    static let hotPink = Color(red: 0.82, green: 0.18, blue: 0.39)
    static let baseBlack = Color(red: 0.035, green: 0.035, blue: 0.045)
    static let elevatedBlack = Color(red: 0.085, green: 0.082, blue: 0.105)
    static let sidebarBlack = Color(red: 0.055, green: 0.055, blue: 0.072)
    static let panelFill = Color.white.opacity(0.035)
    static let panelFillStrong = Color.white.opacity(0.06)
    static let surfaceOutline = Color.white.opacity(0.09)
    static let surfaceInnerHighlight = Color.white.opacity(0.055)
    static let textSecondary = Color.white.opacity(0.70)
    static let textMuted = Color.white.opacity(0.46)
    static let pageGradient = LinearGradient(
        colors: [
            baseBlack,
            Color(red: 0.055, green: 0.052, blue: 0.072),
            Color(red: 0.035, green: 0.034, blue: 0.046),
            Color(red: 0.018, green: 0.018, blue: 0.024),
        ],
        startPoint: .top,
        endPoint: .bottom
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
