import Foundation

struct WorkspaceMemberSnapshotPayload: Codable, Sendable {
    let organizationName: String
    let memberDisplayName: String
    let roleLabel: String
    let trackedTime: TimeInterval
    let focusTime: TimeInterval
    let plannedTime: TimeInterval
    let contextSwitches: Int
    let score: Int
    let snapshotDay: Date
    let weekStart: Date
    let weekEnd: Date
}

struct WorkspaceRankingResponse: Codable, Sendable {
    let organizationName: String?
    let updatedAt: Date?
    let entries: [TeamRankingEntry]
}

private struct WorkspaceSyncSaveResponse: Codable, Sendable {
    let updatedAt: Date?
}

private struct WorkspaceSyncSaveRequest: Codable, Sendable {
    let workspaceSecret: String
    let payload: WorkspaceMemberSnapshotPayload
}

private struct WorkspaceSyncRankingRequest: Codable, Sendable {
    let workspaceSecret: String
    let requestingMemberID: String

    private enum CodingKeys: String, CodingKey {
        case workspaceSecret
        case requestingMemberID = "requestingMemberId"
    }
}

enum WorkspaceSyncError: LocalizedError {
    case invalidBaseURL
    case missingSecret
    case unauthorized
    case invalidResponse
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            "A URL do workspace corporativo nao e valida."
        case .missingSecret:
            "A chave do workspace nao foi encontrada neste Mac."
        case .unauthorized:
            "A chave do workspace nao confere com a configuracao do backend."
        case .invalidResponse:
            "O backend corporativo respondeu sem um payload utilizavel."
        case let .apiError(message):
            message
        }
    }
}

struct WorkspaceSyncService: Sendable {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func push(
        baseURL: String,
        workspaceID: String,
        memberID: String,
        secret: String,
        payload: WorkspaceMemberSnapshotPayload
    ) async throws -> Date? {
        let url = try makeMemberURL(baseURL: baseURL, workspaceID: workspaceID, memberID: memberID)
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(WorkspaceSyncSaveRequest(workspaceSecret: secret, payload: payload))
        let response: WorkspaceSyncSaveResponse = try await perform(request)
        return response.updatedAt
    }

    func fetchRanking(
        baseURL: String,
        workspaceID: String,
        memberID: String,
        secret: String
    ) async throws -> WorkspaceRankingResponse {
        let url = try makeRankingURL(baseURL: baseURL, workspaceID: workspaceID)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(WorkspaceSyncRankingRequest(workspaceSecret: secret, requestingMemberID: memberID))
        return try await perform(request)
    }

    private func makeMemberURL(baseURL: String, workspaceID: String, memberID: String) throws -> URL {
        let base = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let workspace = workspaceID.trimmingCharacters(in: .whitespacesAndNewlines)
        let member = memberID.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !base.isEmpty, !workspace.isEmpty, !member.isEmpty, let baseURL = URL(string: base) else {
            throw WorkspaceSyncError.invalidBaseURL
        }

        return baseURL.appending(path: "/api/workspaces/\(workspace)/members/\(member)")
    }

    private func makeRankingURL(baseURL: String, workspaceID: String) throws -> URL {
        let base = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let workspace = workspaceID.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !base.isEmpty, !workspace.isEmpty, let baseURL = URL(string: base) else {
            throw WorkspaceSyncError.invalidBaseURL
        }

        return baseURL.appending(path: "/api/workspaces/\(workspace)/ranking")
    }

    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 500

        guard (200 ..< 300).contains(statusCode) else {
            if statusCode == 401 || statusCode == 403 {
                throw WorkspaceSyncError.unauthorized
            }

            if let envelope = try? JSONDecoder().decode(WorkspaceSyncAPIErrorEnvelope.self, from: data) {
                throw WorkspaceSyncError.apiError(envelope.message)
            }

            throw WorkspaceSyncError.invalidResponse
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw WorkspaceSyncError.invalidResponse
        }
    }
}

private struct WorkspaceSyncAPIErrorEnvelope: Decodable {
    let message: String
}
