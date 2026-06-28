import Foundation

struct OutlookCalendarSyncResult: Sendable {
    let workspaceLabel: String
    let accountEmail: String
    let calendars: [OutlookCalendarDescriptor]
    let events: [CalendarAgendaItem]
    let syncedAt: Date
}

enum OutlookCalendarIssue: LocalizedError {
    case missingToken
    case invalidResponse
    case unauthorized
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .missingToken:
            "Conexão Microsoft em um clique será liberada em breve."
        case .invalidResponse:
            "O Outlook Calendar respondeu sem um payload utilizavel."
        case .unauthorized:
            "Não foi possível validar a conexão do Outlook. Reconecte quando o conector estiver disponível."
        case let .apiError(message):
            message
        }
    }
}

struct OutlookCalendarService: Sendable {
    private static let calendarWindowDays = 3
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func sync(
        day: Date,
        settings: OutlookCalendarSettings,
        accessToken: String
    ) async throws -> OutlookCalendarSyncResult {
        let token = accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else {
            throw OutlookCalendarIssue.missingToken
        }

        let profile = try await fetchProfile(accessToken: token)
        let remoteCalendars = try await fetchCalendars(accessToken: token)
        let calendars = merge(remoteCalendars: remoteCalendars, existingCalendars: settings.calendars)
        let selectedCalendars = calendars.filter(\.isSelected)
        let events = try await fetchEvents(
            day: day,
            accessToken: token,
            accountEmail: profile.email,
            accountLabel: profile.displayName,
            calendars: selectedCalendars
        )

        return OutlookCalendarSyncResult(
            workspaceLabel: settings.workspaceLabel,
            accountEmail: profile.email,
            calendars: calendars,
            events: events,
            syncedAt: Date()
        )
    }

    private func fetchProfile(accessToken: String) async throws -> OutlookProfile {
        var components = URLComponents(string: "https://graph.microsoft.com/v1.0/me")!
        components.queryItems = [
            URLQueryItem(name: "$select", value: "displayName,mail,userPrincipalName"),
        ]
        let request = authorizedRequest(url: components.url!, accessToken: accessToken)
        let response: OutlookProfileResponse = try await perform(request)
        return OutlookProfile(
            displayName: response.displayName?.nilIfBlank ?? response.userPrincipalName?.nilIfBlank ?? "Outlook",
            email: response.mail?.nilIfBlank ?? response.userPrincipalName?.nilIfBlank ?? "Outlook"
        )
    }

    private func fetchCalendars(accessToken: String) async throws -> [OutlookCalendarDescriptor] {
        var components = URLComponents(string: "https://graph.microsoft.com/v1.0/me/calendars")!
        components.queryItems = [
            URLQueryItem(name: "$select", value: "id,name,color,canEdit,isDefaultCalendar"),
            URLQueryItem(name: "$top", value: "100"),
        ]
        let request = authorizedRequest(url: components.url!, accessToken: accessToken)
        let response: OutlookCalendarListResponse = try await perform(request)

        return response.value
            .map { item in
                OutlookCalendarDescriptor(
                    id: item.id,
                    title: item.name?.nilIfBlank ?? "Outlook Calendar",
                    colorHex: Self.colorHex(for: item.color),
                    isPrimary: item.isDefaultCalendar ?? false,
                    isSelected: true
                )
            }
            .sorted { lhs, rhs in
                if lhs.isPrimary != rhs.isPrimary {
                    return lhs.isPrimary && !rhs.isPrimary
                }
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
    }

    private func fetchEvents(
        day: Date,
        accessToken: String,
        accountEmail: String,
        accountLabel: String,
        calendars: [OutlookCalendarDescriptor]
    ) async throws -> [CalendarAgendaItem] {
        let calendar = Calendar.autoupdatingCurrent
        let startDate = calendar.startOfDay(for: day)
        let endDate = calendar.date(byAdding: .day, value: Self.calendarWindowDays + 1, to: startDate)
            ?? startDate.addingTimeInterval(Double(Self.calendarWindowDays + 1) * 86_400)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let startDateString = formatter.string(from: startDate)
        let endDateString = formatter.string(from: endDate)

        return try await withThrowingTaskGroup(of: [CalendarAgendaItem].self) { group in
            for descriptor in calendars {
                group.addTask {
                    var components = URLComponents(string: "https://graph.microsoft.com/v1.0/me/calendars/\(descriptor.id)/calendarView")!
                    components.queryItems = [
                        URLQueryItem(name: "startDateTime", value: startDateString),
                        URLQueryItem(name: "endDateTime", value: endDateString),
                        URLQueryItem(name: "$top", value: "100"),
                        URLQueryItem(name: "$orderby", value: "start/dateTime"),
                    ]

                    let request = authorizedRequest(url: components.url!, accessToken: accessToken)
                    let response: OutlookEventsResponse = try await perform(request)
                    return response.value.compactMap { event -> CalendarAgendaItem? in
                        guard let start = Self.parse(event.start),
                              let end = Self.parse(event.end) else {
                            return nil
                        }

                        return CalendarAgendaItem(
                            id: "outlook-\(descriptor.id)-\(event.id)",
                            accountID: "outlook-\(accountEmail.lowercased())",
                            accountEmail: accountEmail,
                            accountLabel: accountLabel,
                            calendarID: descriptor.id,
                            calendarTitle: descriptor.title,
                            calendarColorHex: descriptor.colorHex,
                            title: event.subject?.nilIfBlank ?? "Evento do Outlook",
                            location: event.location?.displayName?.nilIfBlank,
                            notes: event.bodyPreview?.nilIfBlank,
                            startDate: start,
                            endDate: max(end, start),
                            isAllDay: event.isAllDay ?? false,
                            htmlLink: event.webLink?.nilIfBlank
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

    private func authorizedRequest(url: URL, accessToken: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private func merge(
        remoteCalendars: [OutlookCalendarDescriptor],
        existingCalendars: [OutlookCalendarDescriptor]
    ) -> [OutlookCalendarDescriptor] {
        let existingSelection = Dictionary(uniqueKeysWithValues: existingCalendars.map { ($0.id, $0) })
        return remoteCalendars.map { remote in
            guard let existing = existingSelection[remote.id] else { return remote }
            var merged = remote
            merged.isSelected = existing.isSelected
            return merged
        }
    }

    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 500

        guard (200 ..< 300).contains(statusCode) else {
            if statusCode == 401 || statusCode == 403 {
                throw OutlookCalendarIssue.unauthorized
            }

            if let envelope = try? JSONDecoder().decode(GraphErrorEnvelope.self, from: data) {
                throw OutlookCalendarIssue.apiError(envelope.error.message)
            }

            throw OutlookCalendarIssue.invalidResponse
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw OutlookCalendarIssue.invalidResponse
        }
    }

    private static func parse(_ payload: OutlookDateTimePayload?) -> Date? {
        guard let payload else { return nil }
        let timeZone = TimeZone(identifier: payload.timeZone ?? "") ?? .autoupdatingCurrent
        let formatters = Self.makeDateFormatters(timeZone: timeZone)

        for formatter in formatters {
            if let date = formatter.date(from: payload.dateTime) {
                return date
            }
        }

        return ISO8601DateFormatter().date(from: payload.dateTime)
    }

    private static func makeDateFormatters(timeZone: TimeZone) -> [DateFormatter] {
        ["yyyy-MM-dd'T'HH:mm:ss.SSSSSSS", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd"]
            .map { format in
                let formatter = DateFormatter()
                formatter.calendar = Calendar(identifier: .gregorian)
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.timeZone = timeZone
                formatter.dateFormat = format
                return formatter
            }
    }

    private static func colorHex(for graphColor: String?) -> String? {
        switch graphColor?.lowercased() {
        case "lightblue":
            "#7DD3FC"
        case "lightgreen":
            "#86EFAC"
        case "lightorange":
            "#FDBA74"
        case "lightgray":
            "#CBD5E1"
        case "lightyellow":
            "#FDE68A"
        case "lightteal":
            "#5EEAD4"
        case "lightpink":
            "#F9A8D4"
        case "lightbrown":
            "#D6B38D"
        default:
            nil
        }
    }
}

private struct OutlookProfile: Sendable {
    let displayName: String
    let email: String
}

private struct OutlookProfileResponse: Decodable {
    let displayName: String?
    let mail: String?
    let userPrincipalName: String?
}

private struct OutlookCalendarListResponse: Decodable {
    let value: [OutlookCalendarResponseItem]
}

private struct OutlookCalendarResponseItem: Decodable {
    let id: String
    let name: String?
    let color: String?
    let isDefaultCalendar: Bool?
}

private struct OutlookEventsResponse: Decodable {
    let value: [OutlookEventPayload]
}

private struct OutlookEventPayload: Decodable {
    let id: String
    let subject: String?
    let bodyPreview: String?
    let webLink: String?
    let isAllDay: Bool?
    let start: OutlookDateTimePayload?
    let end: OutlookDateTimePayload?
    let location: OutlookLocationPayload?
}

private struct OutlookDateTimePayload: Decodable {
    let dateTime: String
    let timeZone: String?
}

private struct OutlookLocationPayload: Decodable {
    let displayName: String?
}

private struct GraphErrorEnvelope: Decodable {
    let error: GraphErrorPayload
}

private struct GraphErrorPayload: Decodable {
    let message: String
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
