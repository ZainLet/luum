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
        if ["active", "canceling"].contains(subscriptionStatus), let expiresAt { return expiresAt < Date() }
        if subscriptionStatus == "trial", let trialEndsAt { return trialEndsAt < Date() }
        guard let lastVerifiedAt else { return true }
        if Date().timeIntervalSince(lastVerifiedAt) > Self.offlineGracePeriod { return true }
        return false
    }

    var lockExplanation: String? {
        if let lockedReason = Self.nonBlank(lockedReason) {
            return "Sua assinatura esta bloqueada: \(lockedReason)."
        }

        if ["canceled", "expired", "trial_expired"].contains(subscriptionStatus) {
            return "Seu acesso expirou. Reative seu plano pelo site para liberar o app."
        }

        if subscriptionStatus == "past_due" {
            return "Seu pagamento esta pendente. Atualize a assinatura pelo site para liberar o app."
        }

        if ["active", "canceling"].contains(subscriptionStatus), let expiresAt, expiresAt < Date() {
            return "Seu periodo de acesso terminou. Revalide ou reative seu plano pelo site."
        }

        if subscriptionStatus == "trial", let trialEndsAt, trialEndsAt < Date() {
            return "Seu trial terminou. Assine pelo site para continuar usando o app."
        }

        guard let lastVerifiedAt else {
            return "Valide seu plano com o Firebase para liberar este recurso neste Mac."
        }

        if Date().timeIntervalSince(lastVerifiedAt) > Self.offlineGracePeriod {
            return "Sua validacao local expirou. Revalide seu plano com o Firebase para liberar este recurso."
        }

        return nil
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
