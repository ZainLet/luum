import Foundation

enum LuumAccountPlan: String, Codable, CaseIterable, Sendable {
    case trial
    case essencial
    case profissional
    case equipes
    case negocios

    init(remoteValue: String?) {
        let value = (remoteValue ?? "trial")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)

        switch value {
        case "essential", "essencial", "basic", "basico":
            self = .essencial
        case "professional", "profissional", "pro":
            self = .profissional
        case "team", "teams", "equipe", "equipes":
            self = .equipes
        case "business", "negocios", "negocio", "enterprise", "empresa":
            self = .negocios
        default:
            self = .trial
        }
    }

    var title: String {
        switch self {
        case .trial: "Trial"
        case .essencial: "Essencial"
        case .profissional: "Profissional"
        case .equipes: "Equipes"
        case .negocios: "Negocios"
        }
    }

    var rank: Int {
        switch self {
        case .trial: 1
        case .essencial: 1
        case .profissional: 2
        case .equipes: 3
        case .negocios: 4
        }
    }

    func includes(_ feature: LuumFeature) -> Bool {
        switch feature {
        case .coreTracking, .search, .classification, .reports:
            true
        case .agendaIntegrations, .focusModes, .reminders, .cloudBackup:
            rank >= LuumAccountPlan.profissional.rank || self == .trial
        case .advancedIntegrations:
            rank >= LuumAccountPlan.equipes.rank || self == .trial
        case .teamWorkspace:
            rank >= LuumAccountPlan.equipes.rank
        case .rawActivityBackup:
            rank >= LuumAccountPlan.negocios.rank
        }
    }
}

enum LuumFeature: String, Codable, Sendable {
    case coreTracking
    case search
    case classification
    case agendaIntegrations
    case focusModes
    case reminders
    case reports
    case cloudBackup
    case rawActivityBackup
    case advancedIntegrations
    case teamWorkspace

    var title: String {
        switch self {
        case .coreTracking: "Monitoramento"
        case .search: "Busca"
        case .classification: "Classificacao"
        case .agendaIntegrations: "Agenda integrada"
        case .focusModes: "Modos de foco"
        case .reminders: "Lembretes"
        case .reports: "Relatorios"
        case .cloudBackup: "Backup Firebase"
        case .rawActivityBackup: "Backup de atividades brutas"
        case .advancedIntegrations: "Integracoes avancadas"
        case .teamWorkspace: "Workspace de equipe"
        }
    }
}

struct LuumAuthSession: Codable, Equatable, Sendable {
    static let offlineGracePeriod: TimeInterval = 24 * 60 * 60

    var uid: String
    var email: String
    var displayName: String?
    var idToken: String
    var refreshToken: String?
    var plan: LuumAccountPlan
    var subscriptionStatus: String
    var lockedReason: String?
    var expiresAt: Date?
    var trialEndsAt: Date?
    var lastVerifiedAt: Date?

    var isLocked: Bool {
        if let lockedReason, !lockedReason.isEmpty { return true }
        if ["canceled", "past_due", "expired", "trial_expired"].contains(subscriptionStatus) { return true }
        if subscriptionStatus == "active", let expiresAt { return expiresAt < Date() }
        if subscriptionStatus == "trial", let trialEndsAt { return trialEndsAt < Date() }
        guard let lastVerifiedAt else { return true }
        if Date().timeIntervalSince(lastVerifiedAt) > Self.offlineGracePeriod { return true }
        return false
    }

    var accountLabel: String {
        Self.nonBlank(displayName) ?? Self.nonBlank(email) ?? uid
    }

    private static func nonBlank(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

struct FirebaseIDTokenPayload: Decodable, Sendable {
    let userID: String?
    let email: String?
    let name: String?
    let issuedAt: TimeInterval?
    let expiresAt: TimeInterval?

    private enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case email
        case name
        case issuedAt = "iat"
        case expiresAt = "exp"
    }
}

struct FirebaseTokenRefreshResponse: Decodable, Sendable {
    let idToken: String
    let refreshToken: String?
    let expiresIn: String?

    private enum CodingKeys: String, CodingKey {
        case idToken = "id_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }
}
