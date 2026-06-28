import Foundation

struct NotionCalendarSyncResult: Sendable {
    let workspaceLabel: String
    let dataSourceIDs: [String]
    let events: [CalendarAgendaItem]
    let syncedAt: Date
}

enum NotionCalendarIssue: LocalizedError {
    case missingToken
    case missingDataSources
    case invalidResponse
    case unauthorized
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .missingToken:
            "Conexão Notion em um clique será liberada em breve."
        case .missingDataSources:
            "Conexão Notion em um clique será liberada em breve."
        case .invalidResponse:
            "O Notion respondeu sem um payload de eventos utilizável."
        case .unauthorized:
            "Não foi possível validar a conexão do Notion. Reconecte quando o conector estiver disponível."
        case let .apiError(message):
            message
        }
    }
}

struct NotionCalendarService: Sendable {
    private static let apiBaseURL = URL(string: "https://api.notion.com/v1")!
    private static let apiVersion = "2025-09-03"
    private static let allDayColorHex = "7c3aed"

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func refresh(
        day: Date,
        settings: NotionCalendarSettings,
        token: String
    ) async throws -> NotionCalendarSyncResult {
        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedToken.isEmpty else {
            throw NotionCalendarIssue.missingToken
        }

        let dataSourceIDs = settings.databaseIDs.compactMap(NotionCalendarSettings.normalizedDatabaseID)
        guard !dataSourceIDs.isEmpty else {
            throw NotionCalendarIssue.missingDataSources
        }

        let calendar = Calendar.autoupdatingCurrent
        let dayStart = calendar.startOfDay(for: day)
        let windowEnd = calendar.date(byAdding: .day, value: 4, to: dayStart) ?? dayStart.addingTimeInterval(345_600)

        var aggregatedEvents: [CalendarAgendaItem] = []
        for dataSourceID in dataSourceIDs {
            let dataSourceTitle = try await fetchDataSourceTitle(dataSourceID: dataSourceID, token: trimmedToken)
            let events = try await queryDataSource(
                dataSourceID: dataSourceID,
                dataSourceTitle: dataSourceTitle,
                token: trimmedToken,
                workspaceLabel: settings.workspaceLabel,
                datePropertyName: settings.datePropertyName,
                titlePropertyName: settings.titlePropertyName,
                from: dayStart,
                to: windowEnd
            )
            aggregatedEvents.append(contentsOf: events)
        }

        return NotionCalendarSyncResult(
            workspaceLabel: settings.workspaceLabel,
            dataSourceIDs: dataSourceIDs,
            events: aggregatedEvents.sorted { lhs, rhs in
                if lhs.startDate == rhs.startDate {
                    return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
                }

                return lhs.startDate < rhs.startDate
            },
            syncedAt: Date()
        )
    }

    private func fetchDataSourceTitle(dataSourceID: String, token: String) async throws -> String {
        let request = try request(
            path: "/data_sources/\(dataSourceID)",
            token: token,
            method: "GET",
            body: nil
        )
        let object = try await performObject(request)

        if let title = Self.extractPlainText(fromTitleFragments: object["title"]) {
            return title
        }

        if let name = object["name"] as? String, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return name
        }

        return "Notion \(String(dataSourceID.prefix(6)).uppercased())"
    }

    private func queryDataSource(
        dataSourceID: String,
        dataSourceTitle: String,
        token: String,
        workspaceLabel: String,
        datePropertyName: String,
        titlePropertyName: String,
        from windowStart: Date,
        to windowEnd: Date
    ) async throws -> [CalendarAgendaItem] {
        let payload = try JSONSerialization.data(
            withJSONObject: [
                "page_size": 100,
            ],
            options: []
        )

        let request = try request(
            path: "/data_sources/\(dataSourceID)/query",
            token: token,
            method: "POST",
            body: payload
        )
        let object = try await performObject(request)
        guard let results = object["results"] as? [[String: Any]] else {
            throw NotionCalendarIssue.invalidResponse
        }

        return results.compactMap { item in
            guard let itemID = item["id"] as? String else { return nil }
            guard let properties = item["properties"] as? [String: Any] else { return nil }
            guard let dateRange = Self.extractDateRange(from: properties, preferredPropertyName: datePropertyName) else { return nil }

            let endDate = dateRange.end ?? (dateRange.isAllDay
                ? Calendar.autoupdatingCurrent.date(byAdding: .day, value: 1, to: dateRange.start)
                : Calendar.autoupdatingCurrent.date(byAdding: .minute, value: 30, to: dateRange.start))
                ?? dateRange.start

            guard endDate > windowStart && dateRange.start < windowEnd else {
                return nil
            }

            let title = Self.extractTitle(from: properties, preferredPropertyName: titlePropertyName)
            let pageURL = item["url"] as? String

            return CalendarAgendaItem(
                id: "notion-\(dataSourceID)-\(itemID)",
                accountID: "notion-\(workspaceLabel.lowercased().replacingOccurrences(of: " ", with: "-"))",
                accountEmail: "Notion",
                accountLabel: workspaceLabel,
                calendarID: dataSourceID,
                calendarTitle: dataSourceTitle,
                calendarColorHex: Self.allDayColorHex,
                title: title,
                location: nil,
                notes: Self.extractPlainText(fromRichText: properties["Description"]) ?? Self.extractPlainText(fromRichText: properties["Notes"]),
                startDate: dateRange.start,
                endDate: endDate,
                isAllDay: dateRange.isAllDay,
                htmlLink: pageURL
            )
        }
    }

    private func request(
        path: String,
        token: String,
        method: String,
        body: Data?
    ) throws -> URLRequest {
        guard let url = URL(string: path, relativeTo: Self.apiBaseURL) else {
            throw NotionCalendarIssue.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(Self.apiVersion, forHTTPHeaderField: "Notion-Version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }

    private func performObject(_ request: URLRequest) async throws -> [String: Any] {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NotionCalendarIssue.invalidResponse
        }

        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw NotionCalendarIssue.unauthorized
            }

            if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = object["message"] as? String {
                throw NotionCalendarIssue.apiError(message)
            }

            throw NotionCalendarIssue.invalidResponse
        }

        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NotionCalendarIssue.invalidResponse
        }
        return object
    }

    private static func extractTitle(
        from properties: [String: Any],
        preferredPropertyName: String
    ) -> String {
        if let preferredProperty = properties[preferredPropertyName] {
            if let preferredTitle = extractPlainText(fromProperty: preferredProperty) {
                return preferredTitle
            }
        }

        for property in properties.values {
            if let title = extractPlainText(fromProperty: property) {
                return title
            }
        }

        return "Pagina do Notion"
    }

    private static func extractDateRange(
        from properties: [String: Any],
        preferredPropertyName: String
    ) -> (start: Date, end: Date?, isAllDay: Bool)? {
        if let preferredProperty = properties[preferredPropertyName],
           let range = parseDateRange(fromProperty: preferredProperty) {
            return range
        }

        for property in properties.values {
            if let range = parseDateRange(fromProperty: property) {
                return range
            }
        }

        return nil
    }

    private static func parseDateRange(fromProperty rawProperty: Any) -> (start: Date, end: Date?, isAllDay: Bool)? {
        guard let property = rawProperty as? [String: Any] else { return nil }
        guard let type = property["type"] as? String, type == "date" else { return nil }
        guard let datePayload = property["date"] as? [String: Any] else { return nil }
        guard let startString = datePayload["start"] as? String else { return nil }

        let start = parseDate(startString)
        let end = (datePayload["end"] as? String).flatMap(parseDate)
        let isAllDay = !startString.contains("T")
        return (start: start, end: end, isAllDay: isAllDay)
    }

    private static func parseDate(_ value: String) -> Date {
        if let date = parseISO8601Date(value) {
            return date
        }

        if let date = parseDayOnlyDate(value) {
            return date
        }

        return Date()
    }

    private static func parseISO8601Date(_ value: String) -> Date? {
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractionalFormatter.date(from: value) {
            return date
        }

        let standardFormatter = ISO8601DateFormatter()
        standardFormatter.formatOptions = [.withInternetDateTime]
        return standardFormatter.date(from: value)
    }

    private static func parseDayOnlyDate(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }

    private static func extractPlainText(fromProperty rawProperty: Any) -> String? {
        guard let property = rawProperty as? [String: Any], let type = property["type"] as? String else {
            return nil
        }

        switch type {
        case "title":
            return extractPlainText(fromTitleFragments: property["title"])
        case "rich_text":
            return extractPlainText(fromRichText: rawProperty)
        default:
            return nil
        }
    }

    private static func extractPlainText(fromTitleFragments rawValue: Any?) -> String? {
        guard let fragments = rawValue as? [[String: Any]] else { return nil }

        let plainText = fragments
            .compactMap { $0["plain_text"] as? String }
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return plainText.isEmpty ? nil : plainText
    }

    private static func extractPlainText(fromRichText rawProperty: Any?) -> String? {
        if let property = rawProperty as? [String: Any],
           let fragments = property["rich_text"] as? [[String: Any]] {
            let plainText = fragments
                .compactMap { $0["plain_text"] as? String }
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return plainText.isEmpty ? nil : plainText
        }

        return nil
    }
}
