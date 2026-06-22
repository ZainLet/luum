import Foundation

struct AIQueryContext: Encodable, Sendable {
    let date: String
    let totalTrackedTime: TimeInterval
    let categoryBreakdown: [AIQueryBreakdownItem]
    let topApps: [AIQueryBreakdownItem]
    let currentActivity: String?
}

struct AIQueryBreakdownItem: Encodable, Sendable {
    let label: String
    let duration: TimeInterval
}

struct AIQueryResponse: Equatable, Sendable {
    let query: String
    let answer: String
}

enum AIQueryServiceError: LocalizedError, Sendable {
    case missingFirebaseAuth
    case invalidEndpoint
    case rejected(String)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .missingFirebaseAuth:
            "Entre no Luum para usar o assistente de IA."
        case .invalidEndpoint:
            "Endpoint do assistente inválido."
        case .rejected(let message):
            message
        case .emptyResponse:
            "O assistente não retornou uma resposta."
        }
    }
}

struct AIQueryService: Sendable {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func query(
        _ question: String,
        context: AIQueryContext,
        baseURL: String,
        firebaseToken: String
    ) async throws -> String {
        guard
            let base = URL(string: baseURL),
            let url = URL(string: "/api/ai/query", relativeTo: base)?.absoluteURL
        else { throw AIQueryServiceError.invalidEndpoint }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(firebaseToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 25

        struct Payload: Encodable {
            let query: String
            let context: AIQueryContext
        }
        request.httpBody = try JSONEncoder().encode(Payload(query: question, context: context))

        let (data, response) = try await session.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 500

        if !(200 ..< 300).contains(statusCode) {
            let message =
                (try? JSONDecoder().decode([String: String].self, from: data))?["error"]
                ?? "Erro HTTP \(statusCode)"
            throw AIQueryServiceError.rejected(message)
        }

        struct ResponsePayload: Decodable { let answer: String }
        let payload = try JSONDecoder().decode(ResponsePayload.self, from: data)
        let answer = payload.answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !answer.isEmpty else { throw AIQueryServiceError.emptyResponse }
        return answer
    }
}
