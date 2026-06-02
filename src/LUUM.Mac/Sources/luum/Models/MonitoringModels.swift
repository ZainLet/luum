import Foundation

enum RuleMatchTarget: String, Codable, CaseIterable, Identifiable, Sendable {
    case applicationName
    case bundleIdentifier
    case domain

    var id: String { rawValue }

    var title: String {
        switch self {
        case .applicationName:
            "Aplicativo"
        case .bundleIdentifier:
            "Bundle ID"
        case .domain:
            "Site"
        }
    }
}

struct CategoryRule: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var categoryID: String
    var matchTarget: RuleMatchTarget
    var pattern: String

    init(
        id: UUID = UUID(),
        categoryID: String,
        matchTarget: RuleMatchTarget,
        pattern: String
    ) {
        self.id = id
        self.categoryID = categoryID
        self.matchTarget = matchTarget
        self.pattern = pattern
    }
}

struct ReminderProfile: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var title: String
    var categoryID: String
    var thresholdMinutes: Int
    var weekdays: [Int]
    var isEnabled: Bool
    var message: String

    init(
        id: UUID = UUID(),
        title: String,
        categoryID: String,
        thresholdMinutes: Int,
        weekdays: [Int],
        isEnabled: Bool,
        message: String
    ) {
        self.id = id
        self.title = title
        self.categoryID = categoryID
        self.thresholdMinutes = thresholdMinutes
        self.weekdays = weekdays
        self.isEnabled = isEnabled
        self.message = message
    }

    static let defaultProfiles = [
        ReminderProfile(
            title: "Trabalho sem pausa",
            categoryID: ActivityCategory.work.id,
            thresholdMinutes: 90,
            weekdays: [2, 3, 4, 5, 6],
            isEnabled: false,
            message: "Hora de levantar, respirar e fazer uma pausa curta."
        ),
        ReminderProfile(
            title: "Entretenimento em excesso",
            categoryID: ActivityCategory.entertainment.id,
            thresholdMinutes: 30,
            weekdays: [1, 2, 3, 4, 5, 6, 7],
            isEnabled: false,
            message: "Voce entrou em uma sequencia longa de entretenimento. Vale voltar para o foco?"
        ),
    ]
}

struct PrivacySettings: Codable, Hashable, Sendable {
    var storesPageTitles: Bool
    var storesFullURLs: Bool
    var retentionDays: Int
    var syncOnlyDomains: Bool

    static let `default` = PrivacySettings(
        storesPageTitles: true,
        storesFullURLs: true,
        retentionDays: 30,
        syncOnlyDomains: true
    )
}

struct CloudSyncSettings: Codable, Hashable, Sendable {
    var isEnabled: Bool
    var endpointURL: String
    var backupID: String
    var syncCategoriesAndRules: Bool
    var syncDailySummaries: Bool
    var syncRawActivities: Bool

    static let `default` = CloudSyncSettings(
        isEnabled: false,
        endpointURL: FirebaseAuthService.defaultBaseURL,
        backupID: "",
        syncCategoriesAndRules: true,
        syncDailySummaries: true,
        syncRawActivities: false
    )
}

struct MonitoringPreferencesSnapshot: Codable, Sendable {
    var categories: [ActivityCategory]
    var categoryRules: [CategoryRule]
    var ignoredApplications: [String]
    var ignoredDomains: [String]
    var reminderProfiles: [ReminderProfile]
    var usageGoals: [UsageGoal]
    var focusProfiles: [FocusModeProfile]
    var notionCalendarSettings: NotionCalendarSettings
    var outlookCalendarSettings: OutlookCalendarSettings
    var clickUpSettings: ClickUpSettings
    var linearSettings: LinearSettings
    var zapierSettings: ZapierSettings
    var teamSettings: TeamSettings
    var privacySettings: PrivacySettings
    var cloudSyncSettings: CloudSyncSettings
    var hasCompletedOnboarding: Bool

    static var `default`: MonitoringPreferencesSnapshot {
        MonitoringPreferencesSnapshot(
            categories: ActivityCategory.builtInCategories,
            categoryRules: ClassificationEngine.defaultRules,
            ignoredApplications: [],
            ignoredDomains: [],
            reminderProfiles: ReminderProfile.defaultProfiles,
            usageGoals: [],
            focusProfiles: [],
            notionCalendarSettings: .default,
            outlookCalendarSettings: .default,
            clickUpSettings: .default,
            linearSettings: .default,
            zapierSettings: .default,
            teamSettings: .default,
            privacySettings: .default,
            cloudSyncSettings: .default,
            hasCompletedOnboarding: false
        )
    }

    private enum CodingKeys: String, CodingKey {
        case categories
        case categoryRules
        case ignoredApplications
        case ignoredDomains
        case reminderProfiles
        case usageGoals
        case focusProfiles
        case notionCalendarSettings
        case outlookCalendarSettings
        case clickUpSettings
        case linearSettings
        case zapierSettings
        case teamSettings
        case privacySettings
        case cloudSyncSettings
        case hasCompletedOnboarding
    }

    init(
        categories: [ActivityCategory],
        categoryRules: [CategoryRule],
        ignoredApplications: [String],
        ignoredDomains: [String],
        reminderProfiles: [ReminderProfile],
        usageGoals: [UsageGoal] = [],
        focusProfiles: [FocusModeProfile] = [],
        notionCalendarSettings: NotionCalendarSettings = .default,
        outlookCalendarSettings: OutlookCalendarSettings = .default,
        clickUpSettings: ClickUpSettings = .default,
        linearSettings: LinearSettings = .default,
        zapierSettings: ZapierSettings = .default,
        teamSettings: TeamSettings = .default,
        privacySettings: PrivacySettings = .default,
        cloudSyncSettings: CloudSyncSettings = .default,
        hasCompletedOnboarding: Bool = false
    ) {
        self.categories = categories
        self.categoryRules = categoryRules
        self.ignoredApplications = ignoredApplications
        self.ignoredDomains = ignoredDomains
        self.reminderProfiles = reminderProfiles
        self.usageGoals = usageGoals
        self.focusProfiles = focusProfiles
        self.notionCalendarSettings = notionCalendarSettings
        self.outlookCalendarSettings = outlookCalendarSettings
        self.clickUpSettings = clickUpSettings
        self.linearSettings = linearSettings
        self.zapierSettings = zapierSettings
        self.teamSettings = teamSettings
        self.privacySettings = privacySettings
        self.cloudSyncSettings = cloudSyncSettings
        self.hasCompletedOnboarding = hasCompletedOnboarding
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        categories = try container.decodeIfPresent([ActivityCategory].self, forKey: .categories) ?? Self.default.categories
        categoryRules = try container.decodeIfPresent([CategoryRule].self, forKey: .categoryRules) ?? Self.default.categoryRules
        ignoredApplications = try container.decodeIfPresent([String].self, forKey: .ignoredApplications) ?? []
        ignoredDomains = try container.decodeIfPresent([String].self, forKey: .ignoredDomains) ?? []
        reminderProfiles = try container.decodeIfPresent([ReminderProfile].self, forKey: .reminderProfiles) ?? Self.default.reminderProfiles
        usageGoals = try container.decodeIfPresent([UsageGoal].self, forKey: .usageGoals) ?? []
        focusProfiles = try container.decodeIfPresent([FocusModeProfile].self, forKey: .focusProfiles) ?? []
        notionCalendarSettings = try container.decodeIfPresent(NotionCalendarSettings.self, forKey: .notionCalendarSettings) ?? .default
        outlookCalendarSettings = try container.decodeIfPresent(OutlookCalendarSettings.self, forKey: .outlookCalendarSettings) ?? .default
        clickUpSettings = try container.decodeIfPresent(ClickUpSettings.self, forKey: .clickUpSettings) ?? .default
        linearSettings = try container.decodeIfPresent(LinearSettings.self, forKey: .linearSettings) ?? .default
        zapierSettings = try container.decodeIfPresent(ZapierSettings.self, forKey: .zapierSettings) ?? .default
        teamSettings = try container.decodeIfPresent(TeamSettings.self, forKey: .teamSettings) ?? .default
        privacySettings = try container.decodeIfPresent(PrivacySettings.self, forKey: .privacySettings) ?? .default
        cloudSyncSettings = try container.decodeIfPresent(CloudSyncSettings.self, forKey: .cloudSyncSettings) ?? .default
        hasCompletedOnboarding = try container.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(categories, forKey: .categories)
        try container.encode(categoryRules, forKey: .categoryRules)
        try container.encode(ignoredApplications, forKey: .ignoredApplications)
        try container.encode(ignoredDomains, forKey: .ignoredDomains)
        try container.encode(reminderProfiles, forKey: .reminderProfiles)
        try container.encode(usageGoals, forKey: .usageGoals)
        try container.encode(focusProfiles, forKey: .focusProfiles)
        try container.encode(notionCalendarSettings, forKey: .notionCalendarSettings)
        try container.encode(outlookCalendarSettings, forKey: .outlookCalendarSettings)
        try container.encode(clickUpSettings, forKey: .clickUpSettings)
        try container.encode(linearSettings, forKey: .linearSettings)
        try container.encode(zapierSettings, forKey: .zapierSettings)
        try container.encode(teamSettings, forKey: .teamSettings)
        try container.encode(privacySettings, forKey: .privacySettings)
        try container.encode(cloudSyncSettings, forKey: .cloudSyncSettings)
        try container.encode(hasCompletedOnboarding, forKey: .hasCompletedOnboarding)
    }

    func normalized() -> MonitoringPreferencesSnapshot {
        var categoriesByID: [String: ActivityCategory] = [:]

        for category in categories {
            let trimmedID = category.id.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedID.isEmpty else { continue }

            let trimmedTitle = category.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedSymbol = category.systemImage.trimmingCharacters(in: .whitespacesAndNewlines)
            categoriesByID[trimmedID] = ActivityCategory(
                id: trimmedID,
                title: trimmedTitle.isEmpty ? "Categoria" : trimmedTitle,
                systemImage: trimmedSymbol.isEmpty ? "tag.fill" : trimmedSymbol,
                colorToken: category.colorToken,
                isBuiltIn: category.isBuiltIn
            )
        }

        for category in ActivityCategory.builtInCategories where categoriesByID[category.id] == nil {
            categoriesByID[category.id] = category
        }

        let orderedCategories = Array(categoriesByID.values).sorted { lhs, rhs in
            if lhs.isBuiltIn == rhs.isBuiltIn {
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }

            return lhs.isBuiltIn && !rhs.isBuiltIn
        }

        let validCategoryIDs = Set(orderedCategories.map(\.id))
        var uniqueRules = Set<RuleKey>()
        var normalizedRules: [CategoryRule] = []

        for rule in categoryRules {
            guard validCategoryIDs.contains(rule.categoryID) else { continue }
            let cleanedPattern = Self.cleanPattern(rule.pattern)
            guard !cleanedPattern.isEmpty else { continue }

            let key = RuleKey(matchTarget: rule.matchTarget, pattern: cleanedPattern)
            guard uniqueRules.insert(key).inserted else { continue }

            normalizedRules.append(
                CategoryRule(
                    id: rule.id,
                    categoryID: rule.categoryID,
                    matchTarget: rule.matchTarget,
                    pattern: cleanedPattern
                )
            )
        }

        var uniqueIgnoredApplications = Set<String>()
        let normalizedIgnoredApplications = ignoredApplications
            .map(Self.cleanPattern)
            .filter { !$0.isEmpty }
            .filter { uniqueIgnoredApplications.insert($0).inserted }

        var uniqueIgnoredDomains = Set<String>()
        let normalizedIgnoredDomains = ignoredDomains
            .map(Self.cleanPattern)
            .filter { !$0.isEmpty }
            .filter { uniqueIgnoredDomains.insert($0).inserted }

        var privacySettings = privacySettings
        privacySettings.retentionDays = min(max(privacySettings.retentionDays, 7), 365)

        var cloudSyncSettings = cloudSyncSettings
        cloudSyncSettings.endpointURL = FirebaseAuthService.defaultBaseURL
        cloudSyncSettings.backupID = cloudSyncSettings.backupID.trimmingCharacters(in: .whitespacesAndNewlines)

        let normalizedGoals = usageGoals
            .filter { validCategoryIDs.contains($0.categoryID) }
            .map {
                var goal = $0
                goal.title = goal.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Meta" : goal.title.trimmingCharacters(in: .whitespacesAndNewlines)
                goal.targetMinutes = max(5, goal.targetMinutes)
                return goal
            }

        let normalizedFocusProfiles = focusProfiles.map { profile in
            var focusProfile = profile
            focusProfile.title = focusProfile.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Modo foco" : focusProfile.title.trimmingCharacters(in: .whitespacesAndNewlines)
            focusProfile.message = focusProfile.message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "O luum detectou uma sequencia longa dentro desse perfil."
                : focusProfile.message.trimmingCharacters(in: .whitespacesAndNewlines)
            focusProfile.categoryIDs = Array(Set(focusProfile.categoryIDs.filter { validCategoryIDs.contains($0) })).sorted()
            focusProfile.thresholdMinutes = max(5, focusProfile.thresholdMinutes)
            focusProfile.weekdays = Array(Set(focusProfile.weekdays.filter { (1 ... 7).contains($0) })).sorted()
            focusProfile.startHour = min(max(focusProfile.startHour, 0), 23)
            focusProfile.endHour = min(max(focusProfile.endHour, 1), 24)
            focusProfile.blockedApplications = Array(Set(focusProfile.blockedApplications.map(Self.cleanPattern).filter { !$0.isEmpty })).sorted()
            focusProfile.blockedDomains = Array(Set(focusProfile.blockedDomains.map(Self.cleanPattern).filter { !$0.isEmpty })).sorted()
            if focusProfile.endHour <= focusProfile.startHour {
                focusProfile.endHour = min(focusProfile.startHour + 1, 24)
            }
            return focusProfile
        }
        .filter { !$0.categoryIDs.isEmpty && !$0.weekdays.isEmpty }

        return MonitoringPreferencesSnapshot(
            categories: orderedCategories,
            categoryRules: normalizedRules,
            ignoredApplications: normalizedIgnoredApplications,
            ignoredDomains: normalizedIgnoredDomains,
            reminderProfiles: reminderProfiles
                .filter { validCategoryIDs.contains($0.categoryID) }
                .map {
                    var reminder = $0
                    reminder.title = reminder.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? "Lembrete"
                        : reminder.title.trimmingCharacters(in: .whitespacesAndNewlines)
                    reminder.message = reminder.message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? "O luum percebeu uma sequencia longa dessa categoria."
                        : reminder.message.trimmingCharacters(in: .whitespacesAndNewlines)
                    reminder.weekdays = Array(Set(reminder.weekdays.filter { (1 ... 7).contains($0) })).sorted()
                    reminder.thresholdMinutes = max(5, reminder.thresholdMinutes)
                    return reminder
                },
            usageGoals: normalizedGoals,
            focusProfiles: normalizedFocusProfiles,
            notionCalendarSettings: notionCalendarSettings.normalized(),
            outlookCalendarSettings: outlookCalendarSettings.normalized(),
            clickUpSettings: clickUpSettings.normalized(),
            linearSettings: linearSettings.normalized(),
            zapierSettings: zapierSettings.normalized(),
            teamSettings: teamSettings.normalized(),
            privacySettings: privacySettings,
            cloudSyncSettings: cloudSyncSettings,
            hasCompletedOnboarding: hasCompletedOnboarding
        )
    }

    func category(for id: String) -> ActivityCategory? {
        categories.first(where: { $0.id == id })
    }

    private static func cleanPattern(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

private struct RuleKey: Hashable {
    let matchTarget: RuleMatchTarget
    let pattern: String
}

struct ReminderWeekday: Identifiable, Hashable {
    let weekday: Int
    let label: String

    var id: Int { weekday }

    static let all: [ReminderWeekday] = [
        ReminderWeekday(weekday: 2, label: "S"),
        ReminderWeekday(weekday: 3, label: "T"),
        ReminderWeekday(weekday: 4, label: "Q"),
        ReminderWeekday(weekday: 5, label: "Q"),
        ReminderWeekday(weekday: 6, label: "S"),
        ReminderWeekday(weekday: 7, label: "S"),
        ReminderWeekday(weekday: 1, label: "D"),
    ]
}
