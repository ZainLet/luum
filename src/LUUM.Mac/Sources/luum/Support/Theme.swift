import SwiftUI

enum LuumTheme {
    // #7c5cff — accent primário do design
    static let accent = Color(red: 0.486, green: 0.361, blue: 1.0)
    // #b9a6ff — estado ativo/hover nos itens de navegação
    static let accentLight = Color(red: 0.725, green: 0.651, blue: 1.0)
    static let secondaryAccent = Color(red: 0.35, green: 0.30, blue: 0.56)
    // #38d5ff — ciano/azul elétrico para indicadores
    static let electricBlue = Color(red: 0.22, green: 0.835, blue: 1.0)
    // #38d5ff alias para o dot de captura ativa
    static let cyanGreen = Color(red: 0.22, green: 0.835, blue: 1.0)
    // #35e6a3 — verde esmeralda para equipe/métricas positivas
    static let emerald = Color(red: 0.208, green: 0.902, blue: 0.639)
    static let hotPink = Color(red: 0.82, green: 0.18, blue: 0.39)

    // #0a0a0d — fundo base da aplicação
    static let baseBlack = Color(red: 0.039, green: 0.039, blue: 0.051)
    // #0e0e12 — superfícies elevadas (cards, overlays)
    static let elevatedBlack = Color(red: 0.055, green: 0.055, blue: 0.071)
    // #101014 — sidebar e painéis laterais
    static let sidebarBlack = Color(red: 0.063, green: 0.063, blue: 0.078)

    static let panelFill = Color.white.opacity(0.04)
    static let panelFillStrong = Color.white.opacity(0.06)
    static let surfaceOutline = Color.white.opacity(0.07)
    static let surfaceInnerHighlight = Color.white.opacity(0.055)
    static let textSecondary = Color.white.opacity(0.68)
    static let textMuted = Color.white.opacity(0.44)

    static let pageGradient = LinearGradient(
        colors: [
            baseBlack,
            Color(red: 0.045, green: 0.043, blue: 0.060),
            Color(red: 0.030, green: 0.030, blue: 0.040),
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
