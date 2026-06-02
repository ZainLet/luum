import Foundation

enum GoalPeriod: String, Codable, CaseIterable, Identifiable, Sendable {
    case daily
    case weekly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .daily:
            "Diaria"
        case .weekly:
            "Semanal"
        }
    }
}

enum GoalDirection: String, Codable, CaseIterable, Identifiable, Sendable {
    case atLeast
    case atMost

    var id: String { rawValue }

    var title: String {
        switch self {
        case .atLeast:
            "Minimo"
        case .atMost:
            "Maximo"
        }
    }
}

struct UsageGoal: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var title: String
    var categoryID: String
    var targetMinutes: Int
    var period: GoalPeriod
    var direction: GoalDirection
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        title: String,
        categoryID: String,
        targetMinutes: Int,
        period: GoalPeriod,
        direction: GoalDirection,
        isEnabled: Bool
    ) {
        self.id = id
        self.title = title
        self.categoryID = categoryID
        self.targetMinutes = targetMinutes
        self.period = period
        self.direction = direction
        self.isEnabled = isEnabled
    }
}

enum FocusModeKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case focus
    case distraction

    var id: String { rawValue }

    var title: String {
        switch self {
        case .focus:
            "Foco"
        case .distraction:
            "Distracao"
        }
    }
}

struct FocusModeProfile: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var title: String
    var kind: FocusModeKind
    var categoryIDs: [String]
    var thresholdMinutes: Int
    var weekdays: [Int]
    var startHour: Int
    var endHour: Int
    var isEnabled: Bool
    var message: String
    var blockedApplications: [String]
    var blockedDomains: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case kind
        case categoryIDs
        case thresholdMinutes
        case weekdays
        case startHour
        case endHour
        case isEnabled
        case message
        case blockedApplications
        case blockedDomains
    }

    init(
        id: UUID = UUID(),
        title: String,
        kind: FocusModeKind,
        categoryIDs: [String],
        thresholdMinutes: Int,
        weekdays: [Int],
        startHour: Int,
        endHour: Int,
        isEnabled: Bool,
        message: String,
        blockedApplications: [String] = [],
        blockedDomains: [String] = []
    ) {
        self.id = id
        self.title = title
        self.kind = kind
        self.categoryIDs = categoryIDs
        self.thresholdMinutes = thresholdMinutes
        self.weekdays = weekdays
        self.startHour = startHour
        self.endHour = endHour
        self.isEnabled = isEnabled
        self.message = message
        self.blockedApplications = blockedApplications
        self.blockedDomains = blockedDomains
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decode(String.self, forKey: .title)
        kind = try container.decode(FocusModeKind.self, forKey: .kind)
        categoryIDs = try container.decode([String].self, forKey: .categoryIDs)
        thresholdMinutes = try container.decode(Int.self, forKey: .thresholdMinutes)
        weekdays = try container.decode([Int].self, forKey: .weekdays)
        startHour = try container.decode(Int.self, forKey: .startHour)
        endHour = try container.decode(Int.self, forKey: .endHour)
        isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        message = try container.decode(String.self, forKey: .message)
        blockedApplications = try container.decodeIfPresent([String].self, forKey: .blockedApplications) ?? []
        blockedDomains = try container.decodeIfPresent([String].self, forKey: .blockedDomains) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(kind, forKey: .kind)
        try container.encode(categoryIDs, forKey: .categoryIDs)
        try container.encode(thresholdMinutes, forKey: .thresholdMinutes)
        try container.encode(weekdays, forKey: .weekdays)
        try container.encode(startHour, forKey: .startHour)
        try container.encode(endHour, forKey: .endHour)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encode(message, forKey: .message)
        try container.encode(blockedApplications, forKey: .blockedApplications)
        try container.encode(blockedDomains, forKey: .blockedDomains)
    }

    var blockedTargetCount: Int {
        blockedApplications.count + blockedDomains.count
    }

    var hasBlockingRules: Bool {
        blockedTargetCount > 0
    }
}

enum FocusBlockTargetKind: String, Hashable, Sendable {
    case application
    case domain

    var title: String {
        switch self {
        case .application:
            "App"
        case .domain:
            "Site"
        }
    }
}

struct FocusBlockMatch: Identifiable, Hashable, Sendable {
    let profile: FocusModeProfile
    let targetKind: FocusBlockTargetKind
    let blockedPattern: String
    let applicationName: String
    let pageTitle: String?
    let domain: String?

    var id: String {
        "\(profile.id.uuidString)-\(targetKind.rawValue)-\(blockedPattern)"
    }

    var title: String {
        switch targetKind {
        case .application:
            applicationName
        case .domain:
            pageTitle ?? domain ?? blockedPattern
        }
    }

    var subtitle: String {
        switch targetKind {
        case .application:
            "Bloqueado pelo perfil \(profile.title)"
        case .domain:
            "\(domain ?? blockedPattern) • perfil \(profile.title)"
        }
    }

    var detail: String {
        switch targetKind {
        case .application:
            "Feche \(applicationName) para manter o foco."
        case .domain:
            "Saia de \(domain ?? blockedPattern) para voltar ao fluxo."
        }
    }
}

enum SuggestionTargetKind: String, Hashable, Sendable {
    case application
    case domain
}

struct ClassificationSuggestion: Identifiable, Hashable, Sendable {
    let id: String
    let kind: SuggestionTargetKind
    let pattern: String
    let recommendedCategory: ActivityCategory
    let sampleCount: Int
    let totalDuration: TimeInterval
    let reason: String
    let confidence: Double
}

struct OnboardingChecklistItem: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let detail: String
    let isDone: Bool
    let actionTitle: String?
}

struct GoalProgress: Identifiable, Hashable, Sendable {
    let goal: UsageGoal
    let category: ActivityCategory
    let currentDuration: TimeInterval

    var id: UUID { goal.id }

    var targetDuration: TimeInterval {
        TimeInterval(goal.targetMinutes * 60)
    }

    var progress: Double {
        guard targetDuration > 0 else { return 0 }
        return currentDuration / targetDuration
    }

    var isMet: Bool {
        switch goal.direction {
        case .atLeast:
            currentDuration >= targetDuration
        case .atMost:
            currentDuration <= targetDuration
        }
    }
}

struct FocusProfileInsight: Identifiable, Hashable, Sendable {
    let profile: FocusModeProfile
    let categories: [ActivityCategory]
    let currentDuration: TimeInterval
    let isWithinSchedule: Bool

    var id: UUID { profile.id }

    var isTriggered: Bool {
        currentDuration >= TimeInterval(profile.thresholdMinutes * 60) && isWithinSchedule && profile.isEnabled
    }

    var messageSubtitle: String {
        let titles = categories.map(\.title).joined(separator: ", ")
        return "\(titles) por \(LuumFormatters.duration(currentDuration))"
    }

    var blockedTargetCount: Int {
        profile.blockedTargetCount
    }
}

struct WeeklyReportDay: Identifiable, Hashable, Sendable {
    let date: Date
    let trackedTime: TimeInterval
    let topCategory: CategoryBreakdown?

    var id: Date { date }
}

struct WeeklyReport: Hashable, Sendable {
    let startDate: Date
    let endDate: Date
    let totalTrackedTime: TimeInterval
    let averageDailyTrackedTime: TimeInterval
    let contextSwitches: Int
    let focusTime: TimeInterval
    let distractionTime: TimeInterval
    let topCategories: [CategoryBreakdown]
    let topApps: [UsageBreakdownItem]
    let topSites: [UsageBreakdownItem]
    let goalProgress: [GoalProgress]
    let days: [WeeklyReportDay]
    let highlights: [String]
}

enum GlobalSearchResultKind: String, Hashable, Sendable {
    case activity
    case agenda
}

struct GlobalSearchResult: Identifiable, Hashable, Sendable {
    let id: String
    let kind: GlobalSearchResultKind
    let date: Date
    let title: String
    let subtitle: String
    let footnote: String
    let category: ActivityCategory?
}

enum ExportFormat: String, CaseIterable, Identifiable, Sendable {
    case json
    case csv

    var id: String { rawValue }

    var title: String {
        rawValue.uppercased()
    }

    var fileExtension: String {
        rawValue
    }
}

enum TimelineMergeDirection: String, Sendable {
    case previous
    case next
}
