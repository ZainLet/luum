import Foundation

struct GoogleCalendarTokens: Codable, Equatable, Sendable {
    let accessToken: String
    let refreshToken: String
    let idToken: String?
    let tokenType: String
    let scope: String
    let expiresAt: Date

    var scopes: [String] {
        scope.split(separator: " ").map(String.init)
    }

    var needsRefresh: Bool {
        expiresAt <= Date().addingTimeInterval(90)
    }
}

struct GoogleCalendarProfile: Codable, Equatable, Sendable {
    let email: String
    let name: String
    let pictureURL: String?
}

struct CalendarAgendaItem: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let title: String
    let location: String?
    let notes: String?
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let htmlLink: String?

    var duration: TimeInterval {
        max(0, endDate.timeIntervalSince(startDate))
    }
}

struct GoogleCalendarSnapshot: Codable, Sendable {
    var clientID: String
    var clientSecret: String
    var tokens: GoogleCalendarTokens?
    var profile: GoogleCalendarProfile?
    var agendaDay: Date?
    var agendaItems: [CalendarAgendaItem]
    var lastSyncAt: Date?

    static let empty = GoogleCalendarSnapshot(
        clientID: "",
        clientSecret: "",
        tokens: nil,
        profile: nil,
        agendaDay: nil,
        agendaItems: [],
        lastSyncAt: nil
    )
}

struct AgendaSummary {
    let day: Date
    let events: [CalendarAgendaItem]
    let isConnected: Bool
    let isConfigured: Bool
    let lastSyncAt: Date?
    let profile: GoogleCalendarProfile?

    var plannedTime: TimeInterval {
        events.reduce(0) { $0 + $1.duration }
    }

    var nextEvent: CalendarAgendaItem? {
        let now = Date()
        return events.first(where: { $0.endDate > now }) ?? events.first
    }
}
