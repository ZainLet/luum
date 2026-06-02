import Foundation

struct CloudDailySummarySnapshot: Codable, Sendable {
    let day: Date
    let totalTrackedTime: TimeInterval
    let categoryDurations: [String: TimeInterval]
}

struct CloudBackupPayload: Codable, Sendable {
    let schemaVersion: Int
    let exportedAt: Date
    let deviceName: String
    let monitoringPreferences: MonitoringPreferencesSnapshot
    let googleCalendarSnapshot: GoogleCalendarSnapshot
    let dailySummaries: [CloudDailySummarySnapshot]
    let rawActivities: [ActivitySample]?
}

struct CloudSyncSnapshotResponse: Codable, Sendable {
    let payload: CloudBackupPayload?
    let updatedAt: Date?
}

struct CloudSyncSaveRequest: Codable, Sendable {
    let payload: CloudBackupPayload
}

struct CloudSyncRestoreRequest: Codable, Sendable {}

enum CloudSyncError: LocalizedError {
    case invalidBaseURL
    case unauthorized
    case invalidResponse
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            "A URL do sync em nuvem nao e valida."
        case .unauthorized:
            "O login Firebase nao autorizou o sync. Entre novamente na conta Luum."
        case .invalidResponse:
            "A resposta do sync em nuvem veio incompleta."
        case let .apiError(message):
            message
        }
    }
}

struct CloudSyncService {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    static func cloudSafePreferences(_ preferences: MonitoringPreferencesSnapshot) -> MonitoringPreferencesSnapshot {
        var sanitized = preferences
        sanitized.zapierSettings.webhookURL = ""
        return sanitized
    }

    static func cloudSafeGoogleCalendarSnapshot(
        clientID: String,
        connections: [GoogleCalendarConnectionSnapshot]
    ) -> GoogleCalendarSnapshot {
        var sanitizedConnections = connections
        for index in sanitizedConnections.indices {
            sanitizedConnections[index].agendaDay = nil
            sanitizedConnections[index].agendaItems = []
            sanitizedConnections[index].legacyTokens = nil
        }

        return GoogleCalendarSnapshot(
            clientID: clientID,
            clientSecret: "",
            connections: sanitizedConnections
        )
    }

    func push(baseURL: String, backupID: String, firebaseToken: String?, payload: CloudBackupPayload) async throws -> Date {
        let url = try makeURL(baseURL: baseURL, backupID: backupID)
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let firebaseToken = Self.nonBlank(firebaseToken) {
            request.setValue("Bearer \(firebaseToken)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONEncoder().encode(CloudSyncSaveRequest(payload: payload))

        let response: CloudSyncSnapshotResponse = try await perform(request)
        guard let updatedAt = response.updatedAt else {
            throw CloudSyncError.invalidResponse
        }
        return updatedAt
    }

    func pull(baseURL: String, backupID: String, firebaseToken: String?) async throws -> CloudBackupPayload? {
        let url = try makeURL(baseURL: baseURL, backupID: backupID)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let firebaseToken = Self.nonBlank(firebaseToken) {
            request.setValue("Bearer \(firebaseToken)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONEncoder().encode(CloudSyncRestoreRequest())

        let response: CloudSyncSnapshotResponse = try await perform(request)
        return response.payload
    }

    private func makeURL(baseURL: String, backupID: String) throws -> URL {
        let trimmedBaseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBackupID = backupID.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedBaseURL.isEmpty,
              !trimmedBackupID.isEmpty,
              let base = FirebaseAuthService.officialBackendURL(from: trimmedBaseURL)
        else {
            throw CloudSyncError.invalidBaseURL
        }

        return base.appending(path: "/api/sync/\(trimmedBackupID)")
    }

    private static func nonBlank(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 500

        guard (200 ..< 300).contains(statusCode) else {
            if statusCode == 401 || statusCode == 403 {
                throw CloudSyncError.unauthorized
            }

            if let envelope = try? JSONDecoder().decode(CloudSyncAPIErrorEnvelope.self, from: data) {
                throw CloudSyncError.apiError(envelope.message)
            }

            throw CloudSyncError.apiError("O sync em nuvem respondeu com status \(statusCode).")
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw CloudSyncError.invalidResponse
        }
    }
}

private struct CloudSyncAPIErrorEnvelope: Decodable {
    let message: String
}
