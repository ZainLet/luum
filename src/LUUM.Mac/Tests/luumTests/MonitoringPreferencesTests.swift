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

@Test
func normalizesBusinessWorkspaceHierarchy() {
    let client = WorkClientProfile(
        name: "  Cliente Alpha  ",
        domain: " Alpha.COM ",
        contract: ClientContractProfile(
            billingModel: .retainer,
            period: .monthly,
            retainerAmount: -100,
            defaultHourlyRate: 250
        )
    )
    let missingClientProject = WorkProjectProfile(clientID: UUID(), title: "Projeto perdido")
    let validProject = WorkProjectProfile(
        clientID: client.id,
        title: "  Implantacao  ",
        hourlyRate: 180,
        tasks: [
            WorkTaskProfile(title: "  Setup  "),
            WorkTaskProfile(title: " "),
        ]
    )

    let snapshot = MonitoringPreferencesSnapshot(
        categories: ActivityCategory.builtInCategories,
        categoryRules: [],
        ignoredApplications: [],
        ignoredDomains: [],
        reminderProfiles: [],
        usageGoals: [],
        focusProfiles: [],
        businessSettings: BusinessWorkspaceSettings(
            clients: [client, WorkClientProfile(name: " ")],
            projects: [missingClientProject, validProject],
            defaultExpenseCategories: [.software, .software],
            defaultExpenseTypes: [.delivery, .delivery],
            defaultRevenueCategories: [.consulting, .consulting]
        ),
        privacySettings: .default,
        cloudSyncSettings: .default,
        hasCompletedOnboarding: false
    ).normalized()

    #expect(snapshot.businessSettings.clients.count == 1)
    #expect(snapshot.businessSettings.clients[0].name == "Cliente Alpha")
    #expect(snapshot.businessSettings.clients[0].domain == "alpha.com")
    #expect(snapshot.businessSettings.clients[0].contract.retainerAmount == 0)
    #expect(snapshot.businessSettings.projects.count == 1)
    #expect(snapshot.businessSettings.projects[0].title == "Implantacao")
    #expect(snapshot.businessSettings.projects[0].tasks.map(\.title) == ["Setup"])
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

    func testNormalizesBusinessWorkspaceHierarchy() {
        let client = WorkClientProfile(
            name: "  Cliente Alpha  ",
            domain: " Alpha.COM ",
            contract: ClientContractProfile(
                billingModel: .retainer,
                period: .monthly,
                retainerAmount: -100,
                defaultHourlyRate: 250
            )
        )
        let missingClientProject = WorkProjectProfile(clientID: UUID(), title: "Projeto perdido")
        let validProject = WorkProjectProfile(
            clientID: client.id,
            title: "  Implantacao  ",
            hourlyRate: 180,
            tasks: [
                WorkTaskProfile(title: "  Setup  "),
                WorkTaskProfile(title: " "),
            ]
        )

        let snapshot = MonitoringPreferencesSnapshot(
            categories: ActivityCategory.builtInCategories,
            categoryRules: [],
            ignoredApplications: [],
            ignoredDomains: [],
            reminderProfiles: [],
            usageGoals: [],
            focusProfiles: [],
            businessSettings: BusinessWorkspaceSettings(
                clients: [client, WorkClientProfile(name: " ")],
                projects: [missingClientProject, validProject],
                defaultExpenseCategories: [.software, .software],
                defaultExpenseTypes: [.delivery, .delivery],
                defaultRevenueCategories: [.consulting, .consulting]
            ),
            privacySettings: .default,
            cloudSyncSettings: .default,
            hasCompletedOnboarding: false
        ).normalized()

        XCTAssertEqual(snapshot.businessSettings.clients.count, 1)
        XCTAssertEqual(snapshot.businessSettings.clients[0].name, "Cliente Alpha")
        XCTAssertEqual(snapshot.businessSettings.clients[0].domain, "alpha.com")
        XCTAssertEqual(snapshot.businessSettings.clients[0].contract.retainerAmount, 0)
        XCTAssertEqual(snapshot.businessSettings.projects.count, 1)
        XCTAssertEqual(snapshot.businessSettings.projects[0].title, "Implantacao")
        XCTAssertEqual(snapshot.businessSettings.projects[0].tasks.map(\.title), ["Setup"])
    }
}
#endif
