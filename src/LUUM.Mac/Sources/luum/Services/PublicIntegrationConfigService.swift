import Foundation

struct PublicIntegrationConfig: Decodable, Sendable {
    let googleCalendar: PublicOAuthClientConfig
    let outlookCalendar: PublicOAuthClientConfig
    let managedOAuth: PublicManagedOAuthConfig
}

struct PublicOAuthClientConfig: Decodable, Sendable {
    let configured: Bool
    let clientID: String?
}

struct PublicManagedOAuthConfig: Decodable, Sendable {
    let googleCalendar: Bool
    let outlookCalendar: Bool
    let notion: Bool
    let clickUp: Bool
    let linear: Bool
    let zapier: Bool
}

enum PublicIntegrationConfigError: LocalizedError {
    case invalidBaseURL
    case routeMissing
    case unavailable(Int)
    case invalidPayload

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            "A API oficial de integrações do Luum não está disponível."
        case .routeMissing:
            "A rota /api/public/integrations não foi encontrada na Vercel. Atualize o deploy do site para liberar conexões em um clique."
        case let .unavailable(statusCode):
            "Não foi possível carregar integrações gerenciadas do Luum agora. HTTP \(statusCode)."
        case .invalidPayload:
            "Não foi possível carregar as integrações gerenciadas do Luum."
        }
    }
}

struct PublicIntegrationConfigService: Sendable {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetch(baseURL: String = FirebaseAuthService.defaultBaseURL) async throws -> PublicIntegrationConfig {
        guard let base = FirebaseAuthService.officialBackendURL(from: baseURL) else {
            throw PublicIntegrationConfigError.invalidBaseURL
        }

        let url = base.appending(path: "/api/public/integrations")
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData

        let (data, response) = try await session.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 500
        if statusCode == 404 {
            throw PublicIntegrationConfigError.routeMissing
        }
        guard (200 ..< 300).contains(statusCode) else {
            throw PublicIntegrationConfigError.unavailable(statusCode)
        }

        do {
            return try JSONDecoder().decode(PublicIntegrationConfig.self, from: data)
        } catch {
            throw PublicIntegrationConfigError.invalidPayload
        }
    }
}
