import Foundation

struct ZapierWebhookPayload: Codable, Sendable {
    let eventType: String
    let sentAt: Date
    let appName: String
    let organizationName: String
    let memberName: String
    let details: [String: String]
}

enum ZapierIssue: LocalizedError {
    case missingWebhook
    case invalidWebhook
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .missingWebhook:
            "Automacoes Zapier guiadas serao liberadas em breve."
        case .invalidWebhook:
            "Não foi possível validar a conexão do Zapier."
        case let .apiError(message):
            message
        }
    }
}

struct ZapierService: Sendable {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func send(webhookURL: String, payload: ZapierWebhookPayload) async throws {
        let trimmedURL = webhookURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty else {
            throw ZapierIssue.missingWebhook
        }
        guard let url = URL(string: trimmedURL) else {
            throw ZapierIssue.invalidWebhook
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)

        let (_, response) = try await session.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 500
        guard (200 ..< 300).contains(statusCode) else {
            throw ZapierIssue.apiError("O webhook do Zapier respondeu com status \(statusCode).")
        }
    }
}
