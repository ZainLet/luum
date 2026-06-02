import Foundation

#if canImport(Testing)
import Testing
@testable import luum

@Test
func normalizesDuplicateCategoriesAndRulesSafely() {
    let duplicateA = ActivityCategory(
        id: "custom",
        title: "Primeira",
        systemImage: "tag.fill",
        colorToken: .violet,
        isBuiltIn: false
    )
    let duplicateB = ActivityCategory(
        id: "custom",
        title: "Segunda",
        systemImage: "paintpalette.fill",
        colorToken: .teal,
        isBuiltIn: false
    )

    let snapshot = MonitoringPreferencesSnapshot(
        categories: [duplicateA, duplicateB],
        categoryRules: [
            CategoryRule(categoryID: "custom", matchTarget: .domain, pattern: "docs.google.com"),
            CategoryRule(categoryID: "custom", matchTarget: .domain, pattern: "docs.google.com"),
        ],
        ignoredApplications: ["Codex", "codex"],
        ignoredDomains: ["youtube.com", "YOUTUBE.COM"],
        reminderProfiles: [],
        usageGoals: [],
        focusProfiles: [],
        privacySettings: .default,
        cloudSyncSettings: .default,
        hasCompletedOnboarding: false
    ).normalized()

    #expect(snapshot.categories.filter { $0.id == "custom" }.count == 1)
    #expect(snapshot.categoryRules.count == 1)
    #expect(snapshot.ignoredApplications == ["codex"])
    #expect(snapshot.ignoredDomains == ["youtube.com"])
}

@Test
func dropsRemindersForMissingCategoriesAndNormalizesWeekdays() {
    let snapshot = MonitoringPreferencesSnapshot(
        categories: ActivityCategory.builtInCategories,
        categoryRules: [],
        ignoredApplications: [],
        ignoredDomains: [],
        reminderProfiles: [
            ReminderProfile(
                title: "  ",
                categoryID: ActivityCategory.work.id,
                thresholdMinutes: 1,
                weekdays: [0, 2, 2, 8, 6],
                isEnabled: true,
                message: " "
            ),
            ReminderProfile(
                title: "Invalido",
                categoryID: "missing",
                thresholdMinutes: 30,
                weekdays: [2],
                isEnabled: true,
                message: "Teste"
            ),
        ],
        usageGoals: [],
        focusProfiles: [],
        privacySettings: .default,
        cloudSyncSettings: .default,
        hasCompletedOnboarding: false
    ).normalized()

    #expect(snapshot.reminderProfiles.count == 1)
    #expect(snapshot.reminderProfiles[0].title == "Lembrete")
    #expect(snapshot.reminderProfiles[0].message == "O luum percebeu uma sequencia longa dessa categoria.")
    #expect(snapshot.reminderProfiles[0].thresholdMinutes == 5)
    #expect(snapshot.reminderProfiles[0].weekdays == [2, 6])
}

@Test
func normalizesFocusShieldRulesInsideProfiles() {
    let profile = FocusModeProfile(
        title: "Foco profundo",
        kind: .focus,
        categoryIDs: [ActivityCategory.work.id],
        thresholdMinutes: 25,
        weekdays: [2, 2, 7],
        startHour: 9,
        endHour: 18,
        isEnabled: true,
        message: "Volte para o foco.",
        blockedApplications: [" Slack ", "slack"],
        blockedDomains: ["YOUTUBE.COM", " youtube.com "]
    )

    let snapshot = MonitoringPreferencesSnapshot(
        categories: ActivityCategory.builtInCategories,
        categoryRules: [],
        ignoredApplications: [],
        ignoredDomains: [],
        reminderProfiles: [],
        usageGoals: [],
        focusProfiles: [profile],
        privacySettings: .default,
        cloudSyncSettings: .default,
        hasCompletedOnboarding: false
    ).normalized()

    #expect(snapshot.focusProfiles.count == 1)
    #expect(snapshot.focusProfiles[0].blockedApplications == ["slack"])
    #expect(snapshot.focusProfiles[0].blockedDomains == ["youtube.com"])
}

@Test
func extractsNotionDataSourceIDsFromFullURLs() {
    let rawURL = "https://www.notion.so/workspace/Calendario-do-time-1234567890abcdef1234567890abcdef?v=feedfacefeedfacefeedfacefeedface"
    let normalizedID = NotionCalendarSettings.normalizedDatabaseID(rawURL)

    #expect(normalizedID == "12345678-90ab-cdef-1234-567890abcdef")
}
#elseif canImport(XCTest)
import XCTest
@testable import luum

final class MonitoringPreferencesTests: XCTestCase {
    func testNormalizesDuplicateCategoriesAndRulesSafely() {
        let duplicateA = ActivityCategory(
            id: "custom",
            title: "Primeira",
            systemImage: "tag.fill",
            colorToken: .violet,
            isBuiltIn: false
        )
        let duplicateB = ActivityCategory(
            id: "custom",
            title: "Segunda",
            systemImage: "paintpalette.fill",
            colorToken: .teal,
            isBuiltIn: false
        )

        let snapshot = MonitoringPreferencesSnapshot(
            categories: [duplicateA, duplicateB],
            categoryRules: [
                CategoryRule(categoryID: "custom", matchTarget: .domain, pattern: "docs.google.com"),
                CategoryRule(categoryID: "custom", matchTarget: .domain, pattern: "docs.google.com"),
            ],
            ignoredApplications: ["Codex", "codex"],
            ignoredDomains: ["youtube.com", "YOUTUBE.COM"],
            reminderProfiles: [],
            usageGoals: [],
            focusProfiles: [],
            privacySettings: .default,
            cloudSyncSettings: .default,
            hasCompletedOnboarding: false
        ).normalized()

        XCTAssertEqual(snapshot.categories.filter { $0.id == "custom" }.count, 1)
        XCTAssertEqual(snapshot.categoryRules.count, 1)
        XCTAssertEqual(snapshot.ignoredApplications, ["codex"])
        XCTAssertEqual(snapshot.ignoredDomains, ["youtube.com"])
    }

    func testDropsRemindersForMissingCategoriesAndNormalizesWeekdays() {
        let snapshot = MonitoringPreferencesSnapshot(
            categories: ActivityCategory.builtInCategories,
            categoryRules: [],
            ignoredApplications: [],
            ignoredDomains: [],
            reminderProfiles: [
                ReminderProfile(
                    title: "  ",
                    categoryID: ActivityCategory.work.id,
                    thresholdMinutes: 1,
                    weekdays: [0, 2, 2, 8, 6],
                    isEnabled: true,
                    message: " "
                ),
                ReminderProfile(
                    title: "Invalido",
                    categoryID: "missing",
                    thresholdMinutes: 30,
                    weekdays: [2],
                    isEnabled: true,
                    message: "Teste"
                ),
            ],
            usageGoals: [],
            focusProfiles: [],
            privacySettings: .default,
            cloudSyncSettings: .default,
            hasCompletedOnboarding: false
        ).normalized()

        XCTAssertEqual(snapshot.reminderProfiles.count, 1)
        XCTAssertEqual(snapshot.reminderProfiles[0].title, "Lembrete")
        XCTAssertEqual(snapshot.reminderProfiles[0].message, "O luum percebeu uma sequencia longa dessa categoria.")
        XCTAssertEqual(snapshot.reminderProfiles[0].thresholdMinutes, 5)
        XCTAssertEqual(snapshot.reminderProfiles[0].weekdays, [2, 6])
    }

    func testNormalizesFocusShieldRulesInsideProfiles() {
        let profile = FocusModeProfile(
            title: "Foco profundo",
            kind: .focus,
            categoryIDs: [ActivityCategory.work.id],
            thresholdMinutes: 25,
            weekdays: [2, 2, 7],
            startHour: 9,
            endHour: 18,
            isEnabled: true,
            message: "Volte para o foco.",
            blockedApplications: [" Slack ", "slack"],
            blockedDomains: ["YOUTUBE.COM", " youtube.com "]
        )

        let snapshot = MonitoringPreferencesSnapshot(
            categories: ActivityCategory.builtInCategories,
            categoryRules: [],
            ignoredApplications: [],
            ignoredDomains: [],
            reminderProfiles: [],
            usageGoals: [],
            focusProfiles: [profile],
            privacySettings: .default,
            cloudSyncSettings: .default,
            hasCompletedOnboarding: false
        ).normalized()

        XCTAssertEqual(snapshot.focusProfiles.count, 1)
        XCTAssertEqual(snapshot.focusProfiles[0].blockedApplications, ["slack"])
        XCTAssertEqual(snapshot.focusProfiles[0].blockedDomains, ["youtube.com"])
    }

    func testExtractsNotionDataSourceIDsFromFullURLs() {
        let rawURL = "https://www.notion.so/workspace/Calendario-do-time-1234567890abcdef1234567890abcdef?v=feedfacefeedfacefeedfacefeedface"
        let normalizedID = NotionCalendarSettings.normalizedDatabaseID(rawURL)

        XCTAssertEqual(normalizedID, "12345678-90ab-cdef-1234-567890abcdef")
    }
}
#endif
