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
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            "A API oficial de integracoes do Luum nao esta disponivel."
        case .invalidResponse:
            "Nao foi possivel carregar as integracoes gerenciadas do Luum."
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
        let (data, response) = try await session.data(from: url)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 500
        guard (200 ..< 300).contains(statusCode) else {
            throw PublicIntegrationConfigError.invalidResponse
        }

        do {
            return try JSONDecoder().decode(PublicIntegrationConfig.self, from: data)
        } catch {
            throw PublicIntegrationConfigError.invalidResponse
        }
    }
}
