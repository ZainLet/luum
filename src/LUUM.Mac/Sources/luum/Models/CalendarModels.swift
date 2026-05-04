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

struct GoogleCalendarProfile: Codable, Equatable, Hashable, Sendable {
    let email: String
    let name: String
    let pictureURL: String?
}

struct GoogleCalendarDescriptor: Identifiable, Codable, Hashable, Sendable {
    let id: String
    var title: String
    var colorHex: String?
    var isPrimary: Bool
    var isSelected: Bool
    var isHidden: Bool
    var accessRole: String?

    init(
        id: String,
        title: String,
        colorHex: String? = nil,
        isPrimary: Bool = false,
        isSelected: Bool = true,
        isHidden: Bool = false,
        accessRole: String? = nil
    ) {
        self.id = id
        self.title = title
        self.colorHex = colorHex
        self.isPrimary = isPrimary
        self.isSelected = isSelected
        self.isHidden = isHidden
        self.accessRole = accessRole
    }
}

struct CalendarAgendaItem: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let accountID: String
    let accountEmail: String
    let accountLabel: String
    let calendarID: String
    let calendarTitle: String
    let calendarColorHex: String?
    let title: String
    let location: String?
    let notes: String?
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let htmlLink: String?

    init(
        id: String,
        accountID: String,
        accountEmail: String,
        accountLabel: String,
        calendarID: String,
        calendarTitle: String,
        calendarColorHex: String?,
        title: String,
        location: String?,
        notes: String?,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool,
        htmlLink: String?
    ) {
        self.id = id
        self.accountID = accountID
        self.accountEmail = accountEmail
        self.accountLabel = accountLabel
        self.calendarID = calendarID
        self.calendarTitle = calendarTitle
        self.calendarColorHex = calendarColorHex
        self.title = title
        self.location = location
        self.notes = notes
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.htmlLink = htmlLink
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case accountID
        case accountEmail
        case accountLabel
        case calendarID
        case calendarTitle
        case calendarColorHex
        case title
        case location
        case notes
        case startDate
        case endDate
        case isAllDay
        case htmlLink
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        accountID = try container.decodeIfPresent(String.self, forKey: .accountID) ?? "legacy-account"
        accountEmail = try container.decodeIfPresent(String.self, forKey: .accountEmail) ?? "Google Agenda"
        accountLabel = try container.decodeIfPresent(String.self, forKey: .accountLabel) ?? accountEmail
        calendarID = try container.decodeIfPresent(String.self, forKey: .calendarID) ?? "primary"
        calendarTitle = try container.decodeIfPresent(String.self, forKey: .calendarTitle) ?? "Principal"
        calendarColorHex = try container.decodeIfPresent(String.self, forKey: .calendarColorHex)
        title = try container.decode(String.self, forKey: .title)
        location = try container.decodeIfPresent(String.self, forKey: .location)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        startDate = try container.decode(Date.self, forKey: .startDate)
        endDate = try container.decode(Date.self, forKey: .endDate)
        isAllDay = try container.decode(Bool.self, forKey: .isAllDay)
        htmlLink = try container.decodeIfPresent(String.self, forKey: .htmlLink)
    }

    var duration: TimeInterval {
        max(0, endDate.timeIntervalSince(startDate))
    }
}

struct GoogleCalendarConnectionSnapshot: Identifiable, Equatable, Sendable {
    var id: String
    var profile: GoogleCalendarProfile
    var calendars: [GoogleCalendarDescriptor]
    var agendaDay: Date?
    var agendaItems: [CalendarAgendaItem]
    var lastSyncAt: Date?
    var isEnabled: Bool
    var legacyTokens: GoogleCalendarTokens?

    init(
        id: String,
        profile: GoogleCalendarProfile,
        calendars: [GoogleCalendarDescriptor],
        agendaDay: Date?,
        agendaItems: [CalendarAgendaItem],
        lastSyncAt: Date?,
        isEnabled: Bool = true,
        legacyTokens: GoogleCalendarTokens? = nil
    ) {
        self.id = id
        self.profile = profile
        self.calendars = calendars
        self.agendaDay = agendaDay
        self.agendaItems = agendaItems
        self.lastSyncAt = lastSyncAt
        self.isEnabled = isEnabled
        self.legacyTokens = legacyTokens
    }
}

extension GoogleCalendarConnectionSnapshot: Codable {
    private enum CodingKeys: String, CodingKey {
        case id
        case profile
        case calendars
        case agendaDay
        case agendaItems
        case lastSyncAt
        case isEnabled
        case tokens
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let profile = try container.decode(GoogleCalendarProfile.self, forKey: .profile)

        id = try container.decodeIfPresent(String.self, forKey: .id) ?? Self.makeID(from: profile.email)
        self.profile = profile
        calendars = try container.decodeIfPresent([GoogleCalendarDescriptor].self, forKey: .calendars) ?? [
            GoogleCalendarDescriptor(id: "primary", title: "Principal", isPrimary: true, isSelected: true),
        ]
        agendaDay = try container.decodeIfPresent(Date.self, forKey: .agendaDay)
        agendaItems = try container.decodeIfPresent([CalendarAgendaItem].self, forKey: .agendaItems) ?? []
        lastSyncAt = try container.decodeIfPresent(Date.self, forKey: .lastSyncAt)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        legacyTokens = try container.decodeIfPresent(GoogleCalendarTokens.self, forKey: .tokens)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(profile, forKey: .profile)
        try container.encode(calendars, forKey: .calendars)
        try container.encodeIfPresent(agendaDay, forKey: .agendaDay)
        try container.encode(agendaItems, forKey: .agendaItems)
        try container.encodeIfPresent(lastSyncAt, forKey: .lastSyncAt)
        try container.encode(isEnabled, forKey: .isEnabled)
    }

    private static func makeID(from email: String) -> String {
        email.lowercased().replacingOccurrences(of: "@", with: "-at-").replacingOccurrences(of: ".", with: "-")
    }
}

struct GoogleCalendarSnapshot: Sendable {
    var clientID: String
    var clientSecret: String
    var connections: [GoogleCalendarConnectionSnapshot]

    static let empty = GoogleCalendarSnapshot(
        clientID: "",
        clientSecret: "",
        connections: []
    )
}

extension GoogleCalendarSnapshot: Codable {
    private enum CodingKeys: String, CodingKey {
        case clientID
        case clientSecret
        case connections
        case tokens
        case profile
        case agendaDay
        case agendaItems
        case lastSyncAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        clientID = try container.decodeIfPresent(String.self, forKey: .clientID) ?? ""
        clientSecret = try container.decodeIfPresent(String.self, forKey: .clientSecret) ?? ""

        if let connections = try container.decodeIfPresent([GoogleCalendarConnectionSnapshot].self, forKey: .connections) {
            self.connections = connections
            return
        }

        let legacyProfile = try container.decodeIfPresent(GoogleCalendarProfile.self, forKey: .profile)
        let legacyTokens = try container.decodeIfPresent(GoogleCalendarTokens.self, forKey: .tokens)
        let legacyAgendaDay = try container.decodeIfPresent(Date.self, forKey: .agendaDay)
        let legacyAgendaItems = try container.decodeIfPresent([CalendarAgendaItem].self, forKey: .agendaItems) ?? []
        let legacyLastSyncAt = try container.decodeIfPresent(Date.self, forKey: .lastSyncAt)

        if let legacyProfile {
            connections = [
                GoogleCalendarConnectionSnapshot(
                    id: legacyProfile.email.lowercased().replacingOccurrences(of: "@", with: "-at-"),
                    profile: legacyProfile,
                    calendars: [
                        GoogleCalendarDescriptor(id: "primary", title: "Principal", isPrimary: true, isSelected: true),
                    ],
                    agendaDay: legacyAgendaDay,
                    agendaItems: legacyAgendaItems,
                    lastSyncAt: legacyLastSyncAt,
                    isEnabled: true,
                    legacyTokens: legacyTokens
                ),
            ]
        } else {
            connections = []
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(clientID, forKey: .clientID)
        try container.encode(clientSecret, forKey: .clientSecret)
        try container.encode(connections, forKey: .connections)
    }
}

struct GoogleCalendarConnectionSummary: Identifiable, Hashable {
    let id: String
    let profile: GoogleCalendarProfile
    let calendars: [GoogleCalendarDescriptor]
    let isEnabled: Bool
    let lastSyncAt: Date?

    var selectedCalendars: [GoogleCalendarDescriptor] {
        calendars.filter(\.isSelected)
    }
}

struct AgendaSummary {
    let day: Date
    let events: [CalendarAgendaItem]
    let isConnected: Bool
    let isConfigured: Bool
    let lastSyncAt: Date?
    let connections: [GoogleCalendarConnectionSummary]

    var plannedTime: TimeInterval {
        events.reduce(0) { $0 + $1.duration }
    }

    var nextEvent: CalendarAgendaItem? {
        let now = Date()
        return events.first(where: { $0.endDate > now }) ?? events.first
    }

    var connectedAccountCount: Int {
        connections.count
    }

    var selectedCalendarCount: Int {
        connections.flatMap(\.selectedCalendars).count
    }
}
