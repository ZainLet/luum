import Foundation

enum WeeklyReportEmailServiceError: LocalizedError {
    case invalidEndpoint
    case invalidResponse
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .invalidEndpoint:
            "A API de relatorio por email nao e valida."
        case .invalidResponse:
            "A API de relatorio por email retornou uma resposta invalida."
        case let .apiError(message):
            message
        }
    }
}

struct WeeklyReportEmailBreakdown: Codable, Sendable {
    let label: String
    let duration: TimeInterval
}

struct WeeklyReportEmailPayload: Codable, Sendable {
    let startDate: String
    let endDate: String
    let totalTrackedTime: TimeInterval
    let averageDailyTrackedTime: TimeInterval
    let contextSwitches: Int
    let focusTime: TimeInterval
    let distractionTime: TimeInterval
    let topCategories: [WeeklyReportEmailBreakdown]
    let topApps: [WeeklyReportEmailBreakdown]
    let topSites: [WeeklyReportEmailBreakdown]
    let highlights: [String]
}

struct WeeklyReportEmailResponse: Decodable, Sendable {
    let ok: Bool
    let emailed: Bool
    let emailID: String?
    let fileName: String
}

struct WeeklyReportEmailService {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func send(
        baseURL: String = FirebaseAuthService.defaultBaseURL,
        firebaseToken: String,
        email: String,
        report: WeeklyReportEmailPayload
    ) async throws -> WeeklyReportEmailResponse {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let base = FirebaseAuthService.officialBackendURL(from: trimmed) else {
            throw WeeklyReportEmailServiceError.invalidEndpoint
        }

        let url = base.appending(path: "/api/reports/weekly-email")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(firebaseToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(
            WeeklyReportEmailRequest(email: email, report: report)
        )

        let (data, response) = try await session.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 500
        guard (200 ..< 300).contains(statusCode) else {
            if statusCode == 404 {
                throw WeeklyReportEmailServiceError.apiError(
                    "A rota de PDF por email nao foi encontrada na Vercel. Atualize o app/site e confira se o deploy inclui /api/reports/weekly-email."
                )
            }
            if let envelope = try? JSONDecoder().decode(WeeklyReportEmailAPIError.self, from: data) {
                throw WeeklyReportEmailServiceError.apiError(envelope.error)
            }
            throw WeeklyReportEmailServiceError.apiError("A API de relatorio por email respondeu com status \(statusCode).")
        }

        do {
            return try JSONDecoder().decode(WeeklyReportEmailResponse.self, from: data)
        } catch {
            throw WeeklyReportEmailServiceError.invalidResponse
        }
    }
}

private struct WeeklyReportEmailRequest: Encodable {
    let email: String
    let report: WeeklyReportEmailPayload
}

private struct WeeklyReportEmailAPIError: Decodable {
    let error: String
}
