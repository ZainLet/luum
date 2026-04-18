import SwiftUI

enum LuumTheme {
    static let accent = Color(red: 0.73, green: 0.41, blue: 1.0)
    static let secondaryAccent = Color(red: 0.49, green: 0.22, blue: 0.9)
    static let electricBlue = Color(red: 0.41, green: 0.73, blue: 1.0)
    static let hotPink = Color(red: 0.96, green: 0.42, blue: 0.84)
    static let surfaceOutline = Color.white.opacity(0.08)
    static let textSecondary = Color.white.opacity(0.72)
    static let textMuted = Color.white.opacity(0.5)
    static let pageGradient = LinearGradient(
        colors: [
            Color.black,
            Color(red: 0.03, green: 0.01, blue: 0.08),
            Color(red: 0.09, green: 0.02, blue: 0.18),
            Color(red: 0.19, green: 0.06, blue: 0.28),
            Color.black,
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

extension ActivityCategory {
    var tint: Color {
        switch self {
        case .work:
            Color(red: 0.48, green: 0.78, blue: 1.0)
        case .entertainment:
            Color(red: 0.92, green: 0.38, blue: 0.82)
        case .communication:
            Color(red: 0.56, green: 0.87, blue: 0.78)
        case .learning:
            Color(red: 1.0, green: 0.79, blue: 0.38)
        case .utilities:
            Color(red: 0.74, green: 0.74, blue: 0.88)
        case .uncategorized:
            LuumTheme.secondaryAccent
        }
    }

    var glassTint: Color {
        tint.opacity(0.35)
    }
}
