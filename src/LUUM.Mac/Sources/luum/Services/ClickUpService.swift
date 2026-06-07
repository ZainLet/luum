import Foundation

struct ClickUpSyncResult: Sendable {
    let workspaceLabel: String
    let listIDs: [String]
    let events: [CalendarAgendaItem]
    let syncedAt: Date
}

enum ClickUpIssue: LocalizedError {
    case missingToken
    case missingLists
    case invalidResponse
    case unauthorized
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .missingToken:
            "Informe um token da API do ClickUp para sincronizar tarefas."
        case .missingLists:
            "Adicione pelo menos um List ID do ClickUp para buscar tarefas."
        case .invalidResponse:
            "O ClickUp respondeu sem um payload utilizavel."
        case .unauthorized:
            "O token do ClickUp foi rejeitado. Revise a integracao."
        case let .apiError(message):
            message
        }
    }
}

struct ClickUpService: Sendable {
    private static let rangeWindowDays = 3
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func sync(
        day: Date,
        settings: ClickUpSettings,
        apiToken: String
    ) async throws -> ClickUpSyncResult {
        let token = apiToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else {
            throw ClickUpIssue.missingToken
        }

        let listIDs = settings.listIDs.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !listIDs.isEmpty else {
            throw ClickUpIssue.missingLists
        }

        let events = try await fetchTasks(
            day: day,
            listIDs: listIDs,
            includeClosed: settings.includeClosedTasks,
            apiToken: token,
            workspaceLabel: settings.workspaceLabel
        )

        return ClickUpSyncResult(
            workspaceLabel: settings.workspaceLabel,
            listIDs: listIDs,
            events: events,
            syncedAt: Date()
        )
    }

    private func fetchTasks(
        day: Date,
        listIDs: [String],
        includeClosed: Bool,
        apiToken: String,
        workspaceLabel: String
    ) async throws -> [CalendarAgendaItem] {
        let calendar = Calendar.autoupdatingCurrent
        let startDate = calendar.startOfDay(for: day)
        let endDate = calendar.date(byAdding: .day, value: Self.rangeWindowDays + 1, to: startDate)
            ?? startDate.addingTimeInterval(Double(Self.rangeWindowDays + 1) * 86_400)
        let dueDateLowerBound = Int64(startDate.timeIntervalSince1970 * 1000)
        let dueDateUpperBound = Int64(endDate.timeIntervalSince1970 * 1000)

        return try await withThrowingTaskGroup(of: [CalendarAgendaItem].self) { group in
            for listID in listIDs {
                group.addTask {
                    var components = URLComponents(string: "https://api.clickup.com/api/v2/list/\(listID)/task")!
                    components.queryItems = [
                        URLQueryItem(name: "include_closed", value: includeClosed ? "true" : "false"),
                        URLQueryItem(name: "subtasks", value: "true"),
                        URLQueryItem(name: "due_date_gt", value: String(dueDateLowerBound)),
                        URLQueryItem(name: "due_date_lt", value: String(dueDateUpperBound)),
                    ]

                    var request = URLRequest(url: components.url!)
                    request.setValue(apiToken, forHTTPHeaderField: "Authorization")
                    request.setValue("application/json", forHTTPHeaderField: "Accept")

                    let response: ClickUpTasksResponse = try await perform(request)
                    return response.tasks.compactMap { task -> CalendarAgendaItem? in
                        let dueDate = task.dueDate.flatMap(Self.date(fromMillisecondsString:))
                        let start = task.startDate.flatMap(Self.date(fromMillisecondsString:)) ?? dueDate
                        guard let resolvedStart = start else { return nil }

                        let end = dueDate ?? calendar.date(byAdding: .minute, value: 30, to: resolvedStart) ?? resolvedStart
                        let isAllDay = task.startDate == nil

                        return CalendarAgendaItem(
                            id: "clickup-\(task.id)",
                            accountID: "clickup-\(workspaceLabel.lowercased().replacingOccurrences(of: " ", with: "-"))",
                            accountEmail: "ClickUp",
                            accountLabel: workspaceLabel,
                            calendarID: task.list?.id ?? listID,
                            calendarTitle: task.list?.name?.nilIfBlank ?? "Lista \(listID)",
                            calendarColorHex: task.status?.color?.nilIfBlank,
                            title: task.name?.nilIfBlank ?? "Tarefa ClickUp",
                            location: nil,
                            notes: task.description?.nilIfBlank,
                            startDate: resolvedStart,
                            endDate: max(end, resolvedStart),
                            isAllDay: isAllDay,
                            htmlLink: task.url?.nilIfBlank
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

    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 500

        guard (200 ..< 300).contains(statusCode) else {
            if statusCode == 401 || statusCode == 403 {
                throw ClickUpIssue.unauthorized
            }

            if let envelope = try? JSONDecoder().decode(ClickUpErrorEnvelope.self, from: data) {
                throw ClickUpIssue.apiError(envelope.err)
            }

            throw ClickUpIssue.invalidResponse
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw ClickUpIssue.invalidResponse
        }
    }

    private static func date(fromMillisecondsString value: String) -> Date? {
        guard let milliseconds = Double(value) else { return nil }
        return Date(timeIntervalSince1970: milliseconds / 1000)
    }
}

private struct ClickUpTasksResponse: Decodable {
    let tasks: [ClickUpTaskPayload]
}

private struct ClickUpTaskPayload: Decodable {
    let id: String
    let name: String?
    let description: String?
    let url: String?
    let dueDate: String?
    let startDate: String?
    let list: ClickUpListPayload?
    let status: ClickUpStatusPayload?

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case url
        case dueDate = "due_date"
        case startDate = "start_date"
        case list
        case status
    }
}

private struct ClickUpListPayload: Decodable {
    let id: String
    let name: String?
}

private struct ClickUpStatusPayload: Decodable {
    let color: String?
}

private struct ClickUpErrorEnvelope: Decodable {
    let err: String
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
