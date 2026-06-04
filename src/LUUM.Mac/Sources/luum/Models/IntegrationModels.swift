import Foundation

enum IntegrationKind: String, CaseIterable, Identifiable, Sendable {
    case aiClassification
    case googleCalendar
    case notionCalendar
    case outlookCalendar
    case clickUp
    case linear
    case zapier
    case firebaseSync

    var id: String { rawValue }

    var title: String {
        switch self {
        case .aiClassification:
            "IA de Classificacao"
        case .googleCalendar:
            "Google Calendar"
        case .notionCalendar:
            "Notion Calendar"
        case .outlookCalendar:
            "Outlook Calendar"
        case .clickUp:
            "ClickUp"
        case .linear:
            "Linear"
        case .zapier:
            "Zapier"
        case .firebaseSync:
            "Firebase Sync"
        }
    }

    var subtitle: String {
        switch self {
        case .aiClassification:
            "Sugestoes automaticas para apps e sites"
        case .googleCalendar:
            "Multiplas contas e calendarios"
        case .notionCalendar:
            "Bancos do Notion com propriedade de data"
        case .outlookCalendar:
            "Calendarios do Microsoft Graph"
        case .clickUp:
            "Tarefas e projetos com prazo"
        case .linear:
            "Issues, ciclos e entregas"
        case .zapier:
            "Automacoes e webhooks reais"
        case .firebaseSync:
            "Backup, equipes e ranking"
        }
    }

    var systemImage: String {
        switch self {
        case .aiClassification:
            "sparkles"
        case .googleCalendar:
            "calendar.badge.clock"
        case .notionCalendar:
            "doc.text.image"
        case .outlookCalendar:
            "envelope.badge"
        case .clickUp:
            "checkmark.seal"
        case .linear:
            "line.3.horizontal.decrease.circle"
        case .zapier:
            "bolt.horizontal.circle"
        case .firebaseSync:
            "cloud.fill"
        }
    }
}

struct AIClassificationSettings: Codable, Hashable, Sendable {
    var isEnabled: Bool
    var providerName: String
    var endpointURL: String
    var model: String
    var minimumConfidence: Double

    static let `default` = AIClassificationSettings(
        isEnabled: false,
        providerName: "Gemini",
        endpointURL: "https://generativelanguage.googleapis.com/v1beta",
        model: "gemini-2.5-flash",
        minimumConfidence: 0.62
    )

    func normalized() -> AIClassificationSettings {
        let cleanProvider = providerName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanEndpoint = endpointURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanModel = model.trimmingCharacters(in: .whitespacesAndNewlines)

        return AIClassificationSettings(
            isEnabled: isEnabled,
            providerName: cleanProvider.isEmpty ? Self.default.providerName : cleanProvider,
            endpointURL: cleanEndpoint.isEmpty ? Self.default.endpointURL : cleanEndpoint.trimmingCharacters(in: CharacterSet(charactersIn: "/")),
            model: cleanModel.isEmpty ? Self.default.model : cleanModel,
            minimumConfidence: min(max(minimumConfidence, 0.1), 0.99)
        )
    }
}

struct OutlookCalendarDescriptor: Identifiable, Codable, Hashable, Sendable {
    let id: String
    var title: String
    var colorHex: String?
    var isPrimary: Bool
    var isSelected: Bool

    init(
        id: String,
        title: String,
        colorHex: String? = nil,
        isPrimary: Bool = false,
        isSelected: Bool = true
    ) {
        self.id = id
        self.title = title
        self.colorHex = colorHex
        self.isPrimary = isPrimary
        self.isSelected = isSelected
    }
}

struct OutlookCalendarSettings: Codable, Hashable, Sendable {
    var isEnabled: Bool
    var workspaceLabel: String
    var accountEmail: String
    var calendars: [OutlookCalendarDescriptor]
    var lastSyncAt: Date?

    static let `default` = OutlookCalendarSettings(
        isEnabled: false,
        workspaceLabel: "Outlook",
        accountEmail: "",
        calendars: [],
        lastSyncAt: nil
    )

    func normalized() -> OutlookCalendarSettings {
        var seenIDs = Set<String>()
        let normalizedCalendars = calendars
            .map { descriptor in
                OutlookCalendarDescriptor(
                    id: descriptor.id.trimmingCharacters(in: .whitespacesAndNewlines),
                    title: descriptor.title.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank ?? "Calendario Outlook",
                    colorHex: descriptor.colorHex?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank,
                    isPrimary: descriptor.isPrimary,
                    isSelected: descriptor.isSelected
                )
            }
            .filter { !$0.id.isEmpty && seenIDs.insert($0.id).inserted }

        return OutlookCalendarSettings(
            isEnabled: isEnabled,
            workspaceLabel: workspaceLabel.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank ?? "Outlook",
            accountEmail: accountEmail.trimmingCharacters(in: .whitespacesAndNewlines),
            calendars: normalizedCalendars,
            lastSyncAt: lastSyncAt
        )
    }
}

struct ClickUpSettings: Codable, Hashable, Sendable {
    var isEnabled: Bool
    var workspaceLabel: String
    var workspaceID: String
    var listIDs: [String]
    var includeClosedTasks: Bool
    var lastSyncAt: Date?

    static let `default` = ClickUpSettings(
        isEnabled: false,
        workspaceLabel: "ClickUp",
        workspaceID: "",
        listIDs: [],
        includeClosedTasks: false,
        lastSyncAt: nil
    )

    func normalized() -> ClickUpSettings {
        var seen = Set<String>()
        let normalizedListIDs = listIDs
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0).inserted }

        return ClickUpSettings(
            isEnabled: isEnabled,
            workspaceLabel: workspaceLabel.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank ?? "ClickUp",
            workspaceID: workspaceID.trimmingCharacters(in: .whitespacesAndNewlines),
            listIDs: normalizedListIDs,
            includeClosedTasks: includeClosedTasks,
            lastSyncAt: lastSyncAt
        )
    }
}

struct LinearSettings: Codable, Hashable, Sendable {
    var isEnabled: Bool
    var workspaceLabel: String
    var workspaceID: String
    var teamIDs: [String]
    var includeCompletedIssues: Bool
    var lastSyncAt: Date?

    static let `default` = LinearSettings(
        isEnabled: false,
        workspaceLabel: "Linear",
        workspaceID: "",
        teamIDs: [],
        includeCompletedIssues: false,
        lastSyncAt: nil
    )

    func normalized() -> LinearSettings {
        var seen = Set<String>()
        let normalizedTeamIDs = teamIDs
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0).inserted }

        return LinearSettings(
            isEnabled: isEnabled,
            workspaceLabel: workspaceLabel.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank ?? "Linear",
            workspaceID: workspaceID.trimmingCharacters(in: .whitespacesAndNewlines),
            teamIDs: normalizedTeamIDs,
            includeCompletedIssues: includeCompletedIssues,
            lastSyncAt: lastSyncAt
        )
    }
}

struct ZapierSettings: Codable, Hashable, Sendable {
    var isEnabled: Bool
    var webhookURL: String
    var sendsFocusEvents: Bool
    var sendsCalendarSyncEvents: Bool
    var sendsWorkspaceRankingEvents: Bool
    var lastDeliveryAt: Date?

    static let `default` = ZapierSettings(
        isEnabled: false,
        webhookURL: "",
        sendsFocusEvents: true,
        sendsCalendarSyncEvents: true,
        sendsWorkspaceRankingEvents: true,
        lastDeliveryAt: nil
    )

    func normalized() -> ZapierSettings {
        ZapierSettings(
            isEnabled: isEnabled,
            webhookURL: webhookURL.trimmingCharacters(in: .whitespacesAndNewlines),
            sendsFocusEvents: sendsFocusEvents,
            sendsCalendarSyncEvents: sendsCalendarSyncEvents,
            sendsWorkspaceRankingEvents: sendsWorkspaceRankingEvents,
            lastDeliveryAt: lastDeliveryAt
        )
    }
}

struct NotionCalendarSettings: Codable, Hashable, Sendable {
    var isEnabled: Bool
    var workspaceLabel: String
    var databaseIDs: [String]
    var datePropertyName: String
    var titlePropertyName: String
    var lastSyncAt: Date?

    static let `default` = NotionCalendarSettings(
        isEnabled: false,
        workspaceLabel: "Notion",
        databaseIDs: [],
        datePropertyName: "Date",
        titlePropertyName: "Name",
        lastSyncAt: nil
    )

    func normalized() -> NotionCalendarSettings {
        var uniqueDatabaseIDs = Set<String>()
        let normalizedDatabaseIDs = databaseIDs
            .compactMap(Self.normalizedDatabaseID)
            .filter { uniqueDatabaseIDs.insert($0).inserted }

        let cleanWorkspace = workspaceLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanDateProperty = datePropertyName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanTitleProperty = titlePropertyName.trimmingCharacters(in: .whitespacesAndNewlines)

        return NotionCalendarSettings(
            isEnabled: isEnabled,
            workspaceLabel: cleanWorkspace.isEmpty ? "Notion" : cleanWorkspace,
            databaseIDs: normalizedDatabaseIDs,
            datePropertyName: cleanDateProperty.isEmpty ? "Date" : cleanDateProperty,
            titlePropertyName: cleanTitleProperty.isEmpty ? "Name" : cleanTitleProperty,
            lastSyncAt: lastSyncAt
        )
    }

    static func normalizedDatabaseID(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let candidate: String
        if let url = URL(string: trimmed), let lastPath = url.pathComponents.last {
            candidate = lastPath
        } else {
            candidate = trimmed
        }

        let lowercased = candidate.lowercased()
        if let range = lowercased.range(
            of: #"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}"#,
            options: .regularExpression
        ) {
            return String(lowercased[range])
        }

        let compact = lowercased.replacingOccurrences(of: "-", with: "")
        guard let range = compact.range(of: #"[0-9a-f]{32}"#, options: .regularExpression) else {
            return nil
        }

        return formatUUIDString(fromCompactID: String(compact[range]))
    }

    private static func formatUUIDString(fromCompactID compactID: String) -> String {
        let segments = [
            String(compactID.prefix(8)),
            String(compactID.dropFirst(8).prefix(4)),
            String(compactID.dropFirst(12).prefix(4)),
            String(compactID.dropFirst(16).prefix(4)),
            String(compactID.dropFirst(20).prefix(12)),
        ]

        return segments.joined(separator: "-")
    }
}

struct TeamSettings: Codable, Hashable, Sendable {
    var organizationName: String
    var memberDisplayName: String
    var roleLabel: String
    var sharesAnonymousMetrics: Bool
    var workspaceID: String
    var workspaceMemberID: String
    var workspaceEndpointURL: String
    var automaticallySyncWorkspace: Bool

    static let `default` = TeamSettings(
        organizationName: "Minha empresa",
        memberDisplayName: Host.current().localizedName ?? "Voce",
        roleLabel: "Individual",
        sharesAnonymousMetrics: false,
        workspaceID: "",
        workspaceMemberID: Self.makeDefaultMemberID(from: Host.current().localizedName ?? "voce"),
        workspaceEndpointURL: FirebaseAuthService.defaultBaseURL,
        automaticallySyncWorkspace: false
    )

    func normalized() -> TeamSettings {
        let cleanOrg = organizationName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanName = memberDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanRole = roleLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanWorkspaceID = workspaceID.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanWorkspaceMemberID = workspaceMemberID.trimmingCharacters(in: .whitespacesAndNewlines)

        return TeamSettings(
            organizationName: cleanOrg.isEmpty ? "Minha empresa" : cleanOrg,
            memberDisplayName: cleanName.isEmpty ? "Voce" : cleanName,
            roleLabel: cleanRole.isEmpty ? "Individual" : cleanRole,
            sharesAnonymousMetrics: sharesAnonymousMetrics,
            workspaceID: cleanWorkspaceID,
            workspaceMemberID: cleanWorkspaceMemberID.isEmpty ? Self.makeDefaultMemberID(from: cleanName) : cleanWorkspaceMemberID,
            workspaceEndpointURL: FirebaseAuthService.defaultBaseURL,
            automaticallySyncWorkspace: automaticallySyncWorkspace
        )
    }

    private static func makeDefaultMemberID(from label: String) -> String {
        let allowed = label
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")

        return allowed.isEmpty ? UUID().uuidString.lowercased() : allowed
    }
}

struct TeamRankingEntry: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let displayName: String
    let roleLabel: String
    let trackedTime: TimeInterval
    let focusTime: TimeInterval
    let plannedTime: TimeInterval
    let contextSwitches: Int
    let score: Int
    let isCurrentUser: Bool

    var utilization: Double {
        guard plannedTime > 0 else { return trackedTime > 0 ? 1 : 0 }
        return min(trackedTime / plannedTime, 1.5)
    }
}

extension String {
    fileprivate var nilIfBlank: String? {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
