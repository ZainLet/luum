import Foundation

struct LinearSyncResult: Sendable {
    let workspaceLabel: String
    let teamIDs: [String]
    let events: [CalendarAgendaItem]
    let syncedAt: Date
}

enum LinearIssue: LocalizedError {
    case missingToken
    case missingTeams
    case invalidResponse
    case unauthorized
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .missingToken:
            "Informe uma API key do Linear para sincronizar issues."
        case .missingTeams:
            "Adicione pelo menos um Team ID do Linear para puxar as issues."
        case .invalidResponse:
            "O Linear respondeu sem um payload utilizavel."
        case .unauthorized:
            "A API key do Linear foi rejeitada."
        case let .apiError(message):
            message
        }
    }
}

struct LinearService: Sendable {
    private static let rangeWindowDays = 3
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func sync(
        day: Date,
        settings: LinearSettings,
        apiKey: String
    ) async throws -> LinearSyncResult {
        let token = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else {
            throw LinearIssue.missingToken
        }

        let teamIDs = settings.teamIDs.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !teamIDs.isEmpty else {
            throw LinearIssue.missingTeams
        }

        let events = try await fetchIssues(
            day: day,
            teamIDs: teamIDs,
            includeCompleted: settings.includeCompletedIssues,
            apiKey: token,
            workspaceLabel: settings.workspaceLabel
        )

        return LinearSyncResult(
            workspaceLabel: settings.workspaceLabel,
            teamIDs: teamIDs,
            events: events,
            syncedAt: Date()
        )
    }

    private func fetchIssues(
        day: Date,
        teamIDs: [String],
        includeCompleted: Bool,
        apiKey: String,
        workspaceLabel: String
    ) async throws -> [CalendarAgendaItem] {
        let calendar = Calendar.autoupdatingCurrent
        let rangeStart = calendar.startOfDay(for: day)
        let rangeEnd = calendar.date(byAdding: .day, value: Self.rangeWindowDays + 1, to: rangeStart)
            ?? rangeStart.addingTimeInterval(Double(Self.rangeWindowDays + 1) * 86_400)

        return try await withThrowingTaskGroup(of: [CalendarAgendaItem].self) { group in
            for teamID in teamIDs {
                group.addTask {
                    let request = try makeTeamIssuesRequest(teamID: teamID, apiKey: apiKey)
                    let response: LinearGraphQLResponse<LinearTeamQueryPayload> = try await perform(request)

                    guard let nodes = response.data?.team?.issues.nodes,
                          let team = response.data?.team else {
                        return []
                    }

                    return nodes.compactMap { issue -> CalendarAgendaItem? in
                        guard let dueDate = Self.parseDay(issue.dueDate) else { return nil }
                        guard dueDate >= rangeStart && dueDate < rangeEnd else { return nil }
                        if !includeCompleted, issue.completedAt != nil {
                            return nil
                        }

                        let endDate = calendar.date(byAdding: .day, value: 1, to: dueDate) ?? dueDate
                        return CalendarAgendaItem(
                            id: "linear-\(issue.id)",
                            accountID: "linear-\(workspaceLabel.lowercased().replacingOccurrences(of: " ", with: "-"))",
                            accountEmail: "Linear",
                            accountLabel: workspaceLabel,
                            calendarID: teamID,
                            calendarTitle: team.name?.nilIfBlank ?? "Time \(teamID)",
                            calendarColorHex: issue.state?.color?.nilIfBlank,
                            title: issue.title?.nilIfBlank ?? issue.identifier,
                            location: nil,
                            notes: issue.identifier,
                            startDate: dueDate,
                            endDate: endDate,
                            isAllDay: true,
                            htmlLink: issue.url?.nilIfBlank
                        )
                    }
                }
            }

            return try await group.reduce(into: []) { partialResult, value in
                partialResult.append(contentsOf: value)
            }
            .sorted { $0.startDate < $1.startDate }
        }
    }

    private func makeTeamIssuesRequest(teamID: String, apiKey: String) throws -> URLRequest {
        var request = URLRequest(url: URL(string: "https://api.linear.app/graphql")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "Authorization")

        let query = """
        query TeamIssues($teamId: String!) {
          team(id: $teamId) {
            id
            name
            issues(first: 100) {
              nodes {
                id
                identifier
                title
                dueDate
                completedAt
                url
                state {
                  name
                  color
                }
              }
            }
          }
        }
        """

        let payload = LinearGraphQLRequest(
            query: query,
            variables: ["teamId": teamID]
        )
        request.httpBody = try JSONEncoder().encode(payload)
        return request
    }

    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 500

        guard (200 ..< 300).contains(statusCode) else {
            if statusCode == 401 || statusCode == 403 {
                throw LinearIssue.unauthorized
            }

            throw LinearIssue.invalidResponse
        }

        let decoded = try? JSONDecoder().decode(LinearErrorEnvelope.self, from: data)
        if let firstMessage = decoded?.errors.first?.message {
            throw LinearIssue.apiError(firstMessage)
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw LinearIssue.invalidResponse
        }
    }

    private static func parseDay(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }
}

private struct LinearGraphQLRequest: Encodable {
    let query: String
    let variables: [String: String]
}

private struct LinearGraphQLResponse<T: Decodable>: Decodable {
    let data: T?
}

private struct LinearTeamQueryPayload: Decodable {
    let team: LinearTeamPayload?
}

private struct LinearTeamPayload: Decodable {
    let id: String
    let name: String?
    let issues: LinearIssueConnectionPayload
}

private struct LinearIssueConnectionPayload: Decodable {
    let nodes: [LinearIssuePayload]
}

private struct LinearIssuePayload: Decodable {
    let id: String
    let identifier: String
    let title: String?
    let dueDate: String?
    let completedAt: String?
    let url: String?
    let state: LinearIssueStatePayload?
}

private struct LinearIssueStatePayload: Decodable {
    let name: String?
    let color: String?
}

private struct LinearErrorEnvelope: Decodable {
    let errors: [LinearErrorPayload]
}

private struct LinearErrorPayload: Decodable {
    let message: String
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
