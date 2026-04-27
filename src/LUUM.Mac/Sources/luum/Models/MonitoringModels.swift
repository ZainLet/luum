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

struct MonitoringPreferencesSnapshot: Codable, Sendable {
    var categories: [ActivityCategory]
    var categoryRules: [CategoryRule]
    var ignoredApplications: [String]
    var ignoredDomains: [String]
    var reminderProfiles: [ReminderProfile]

    static var `default`: MonitoringPreferencesSnapshot {
        MonitoringPreferencesSnapshot(
            categories: ActivityCategory.builtInCategories,
            categoryRules: ClassificationEngine.defaultRules,
            ignoredApplications: [],
            ignoredDomains: [],
            reminderProfiles: ReminderProfile.defaultProfiles
        )
    }

    func normalized() -> MonitoringPreferencesSnapshot {
        var categoriesByID = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })

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

        return MonitoringPreferencesSnapshot(
            categories: orderedCategories,
            categoryRules: categoryRules.filter { validCategoryIDs.contains($0.categoryID) && !$0.pattern.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty },
            ignoredApplications: ignoredApplications.map(Self.cleanPattern).filter { !$0.isEmpty },
            ignoredDomains: ignoredDomains.map(Self.cleanPattern).filter { !$0.isEmpty },
            reminderProfiles: reminderProfiles
                .filter { validCategoryIDs.contains($0.categoryID) }
                .map {
                    var reminder = $0
                    reminder.weekdays = reminder.weekdays.filter { (1 ... 7).contains($0) }
                    reminder.thresholdMinutes = max(5, reminder.thresholdMinutes)
                    return reminder
                }
        )
    }

    func category(for id: String) -> ActivityCategory? {
        categories.first(where: { $0.id == id })
    }

    private static func cleanPattern(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
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
