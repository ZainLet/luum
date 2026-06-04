import Foundation

#if canImport(Testing)
import Testing
@testable import luum

@Test
func categorizesWorkDomainBeforeBrowserName() {
    let engine = ClassificationEngine()

    let category = engine.classify(
        applicationName: "Safari",
        bundleIdentifier: "com.apple.Safari",
        webURL: "https://github.com/ZainLet/luum"
    )

    #expect(category == .work)
}

@Test
func categorizesEntertainmentApplicationsWithoutURL() {
    let engine = ClassificationEngine()

    let category = engine.classify(
        applicationName: "Spotify",
        bundleIdentifier: "com.spotify.client",
        webURL: nil
    )

    #expect(category == .entertainment)
}

@Test
func categorizesProfessionalCreativeApplicationsByDefault() {
    let engine = ClassificationEngine()

    let category = engine.classify(
        applicationName: "Adobe Premiere Pro 2026",
        bundleIdentifier: "com.adobe.PremierePro",
        webURL: nil
    )

    #expect(category == .work)
}

@Test
func categorizesProductivityUtilitiesByDefault() {
    let engine = ClassificationEngine()

    let category = engine.classify(
        applicationName: "Todoist",
        bundleIdentifier: "com.todoist.mac.Todoist",
        webURL: nil
    )

    #expect(category == .utilities)
}

@Test
func ignoresSystemApplicationsByDefault() {
    let engine = ClassificationEngine()

    let ignored = engine.isIgnored(
        applicationName: "System Settings",
        bundleIdentifier: "com.apple.systemsettings",
        webURL: nil,
        preferences: .default
    )

    #expect(ignored == true)
}

@Test
func prioritizesManualRuleOverrides() {
    let engine = ClassificationEngine()
    var preferences = MonitoringPreferencesSnapshot.default
    preferences.categoryRules.insert(
        CategoryRule(
            categoryID: ActivityCategory.work.id,
            matchTarget: .domain,
            pattern: "youtube.com"
        ),
        at: 0
    )

    let category = engine.classify(
        applicationName: "Safari",
        bundleIdentifier: "com.apple.Safari",
        webURL: "https://www.youtube.com/watch?v=123",
        preferences: preferences
    )

    #expect(category == .work)
}

@Test
func respectsManualCategoryOverridesOnSamples() {
    let engine = ClassificationEngine()
    let sample = ActivitySample(
        startDate: Date(timeIntervalSince1970: 1_700_000_000),
        endDate: Date(timeIntervalSince1970: 1_700_000_600),
        applicationName: "Safari",
        bundleIdentifier: "com.apple.Safari",
        webURL: "https://youtube.com/watch?v=123",
        webDomain: "youtube.com",
        pageTitle: "Video",
        source: .browserURL,
        manualCategoryID: ActivityCategory.work.id
    )

    let category = engine.classify(
        sample: sample,
        preferences: .default
    )

    #expect(category == .work)
}

@Test
func keepsBrowserDomainsVisibleWhenBrowserAppIsIgnored() {
    let engine = ClassificationEngine()
    var preferences = MonitoringPreferencesSnapshot.default
    preferences.ignoredApplications = ["google chrome"]

    let ignored = engine.isIgnored(
        applicationName: "Google Chrome",
        bundleIdentifier: "com.google.Chrome",
        webURL: "https://github.com/ZainLet/luum",
        preferences: preferences
    )

    #expect(ignored == false)
}

@Test
func stillIgnoresBrowserShellWithoutTrackedURL() {
    let engine = ClassificationEngine()
    var preferences = MonitoringPreferencesSnapshot.default
    preferences.ignoredApplications = ["google chrome"]

    let ignored = engine.isIgnored(
        applicationName: "Google Chrome",
        bundleIdentifier: "com.google.Chrome",
        webURL: nil,
        preferences: preferences
    )

    #expect(ignored == true)
}

@Test
func stillIgnoresBlockedDomainsInsideBrowsers() {
    let engine = ClassificationEngine()
    var preferences = MonitoringPreferencesSnapshot.default
    preferences.ignoredApplications = ["google chrome"]
    preferences.ignoredDomains = ["github.com"]

    let ignored = engine.isIgnored(
        applicationName: "Google Chrome",
        bundleIdentifier: "com.google.Chrome",
        webURL: "https://github.com/ZainLet/luum",
        preferences: preferences
    )

    #expect(ignored == true)
}

@Test
func migratesLegacyGoogleCalendarSnapshot() throws {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let legacy = LegacyGoogleCalendarSnapshotFixture(
        clientID: "client-id",
        clientSecret: "client-secret",
        tokens: GoogleCalendarTokens(
            accessToken: "access",
            refreshToken: "refresh",
            idToken: nil,
            tokenType: "Bearer",
            scope: "calendar",
            expiresAt: now.addingTimeInterval(3600)
        ),
        profile: GoogleCalendarProfile(
            email: "team@luum.app",
            name: "Luum Team",
            pictureURL: nil
        ),
        agendaDay: now,
        agendaItems: [],
        lastSyncAt: now
    )

    let data = try JSONEncoder().encode(legacy)
    let snapshot = try JSONDecoder().decode(GoogleCalendarSnapshot.self, from: data)

    #expect(snapshot.clientID == "client-id")
    #expect(snapshot.connections.count == 1)
    #expect(snapshot.connections.first?.profile.email == "team@luum.app")
    #expect(snapshot.connections.first?.legacyTokens?.refreshToken == "refresh")
    #expect(snapshot.connections.first?.calendars.first?.id == "primary")
}

@Test
func decodesLegacyAgendaItemsWithoutAccountMetadata() throws {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let legacy = LegacyAgendaItemFixture(
        id: "event-1",
        title: "Daily",
        location: nil,
        notes: nil,
        startDate: now,
        endDate: now.addingTimeInterval(1800),
        isAllDay: false,
        htmlLink: nil
    )

    let data = try JSONEncoder().encode(legacy)
    let item = try JSONDecoder().decode(CalendarAgendaItem.self, from: data)

    #expect(item.accountID == "legacy-account")
    #expect(item.calendarID == "primary")
    #expect(item.calendarTitle == "Principal")
}

private struct LegacyGoogleCalendarSnapshotFixture: Encodable {
    let clientID: String
    let clientSecret: String
    let tokens: GoogleCalendarTokens
    let profile: GoogleCalendarProfile
    let agendaDay: Date
    let agendaItems: [CalendarAgendaItem]
    let lastSyncAt: Date
}

private struct LegacyAgendaItemFixture: Encodable {
    let id: String
    let title: String
    let location: String?
    let notes: String?
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let htmlLink: String?
}
#elseif canImport(XCTest)
import XCTest
@testable import luum

final class ClassificationEngineTests: XCTestCase {
    func testCategorizesWorkDomainBeforeBrowserName() {
        let engine = ClassificationEngine()

        let category = engine.classify(
            applicationName: "Safari",
            bundleIdentifier: "com.apple.Safari",
            webURL: "https://github.com/ZainLet/luum"
        )

        XCTAssertEqual(category, .work)
    }

    func testCategorizesEntertainmentApplicationsWithoutURL() {
        let engine = ClassificationEngine()

        let category = engine.classify(
            applicationName: "Spotify",
            bundleIdentifier: "com.spotify.client",
            webURL: nil
        )

        XCTAssertEqual(category, .entertainment)
    }

    func testCategorizesProfessionalCreativeApplicationsByDefault() {
        let engine = ClassificationEngine()

        let category = engine.classify(
            applicationName: "Adobe Premiere Pro 2026",
            bundleIdentifier: "com.adobe.PremierePro",
            webURL: nil
        )

        XCTAssertEqual(category, .work)
    }

    func testCategorizesProductivityUtilitiesByDefault() {
        let engine = ClassificationEngine()

        let category = engine.classify(
            applicationName: "Todoist",
            bundleIdentifier: "com.todoist.mac.Todoist",
            webURL: nil
        )

        XCTAssertEqual(category, .utilities)
    }

    func testIgnoresSystemApplicationsByDefault() {
        let engine = ClassificationEngine()

        let ignored = engine.isIgnored(
            applicationName: "System Settings",
            bundleIdentifier: "com.apple.systemsettings",
            webURL: nil,
            preferences: .default
        )

        XCTAssertTrue(ignored)
    }

    func testPrioritizesManualRuleOverrides() {
        let engine = ClassificationEngine()
        var preferences = MonitoringPreferencesSnapshot.default
        preferences.categoryRules.insert(
            CategoryRule(
                categoryID: ActivityCategory.work.id,
                matchTarget: .domain,
                pattern: "youtube.com"
            ),
            at: 0
        )

        let category = engine.classify(
            applicationName: "Safari",
            bundleIdentifier: "com.apple.Safari",
            webURL: "https://www.youtube.com/watch?v=123",
            preferences: preferences
        )

        XCTAssertEqual(category, .work)
    }

    func testRespectsManualCategoryOverridesOnSamples() {
        let engine = ClassificationEngine()
        let sample = ActivitySample(
            startDate: Date(timeIntervalSince1970: 1_700_000_000),
            endDate: Date(timeIntervalSince1970: 1_700_000_600),
            applicationName: "Safari",
            bundleIdentifier: "com.apple.Safari",
            webURL: "https://youtube.com/watch?v=123",
            webDomain: "youtube.com",
            pageTitle: "Video",
            source: .browserURL,
            manualCategoryID: ActivityCategory.work.id
        )

        let category = engine.classify(
            sample: sample,
            preferences: .default
        )

        XCTAssertEqual(category, .work)
    }

    func testKeepsBrowserDomainsVisibleWhenBrowserAppIsIgnored() {
        let engine = ClassificationEngine()
        var preferences = MonitoringPreferencesSnapshot.default
        preferences.ignoredApplications = ["google chrome"]

        let ignored = engine.isIgnored(
            applicationName: "Google Chrome",
            bundleIdentifier: "com.google.Chrome",
            webURL: "https://github.com/ZainLet/luum",
            preferences: preferences
        )

        XCTAssertFalse(ignored)
    }

    func testStillIgnoresBrowserShellWithoutTrackedURL() {
        let engine = ClassificationEngine()
        var preferences = MonitoringPreferencesSnapshot.default
        preferences.ignoredApplications = ["google chrome"]

        let ignored = engine.isIgnored(
            applicationName: "Google Chrome",
            bundleIdentifier: "com.google.Chrome",
            webURL: nil,
            preferences: preferences
        )

        XCTAssertTrue(ignored)
    }

    func testStillIgnoresBlockedDomainsInsideBrowsers() {
        let engine = ClassificationEngine()
        var preferences = MonitoringPreferencesSnapshot.default
        preferences.ignoredApplications = ["google chrome"]
        preferences.ignoredDomains = ["github.com"]

        let ignored = engine.isIgnored(
            applicationName: "Google Chrome",
            bundleIdentifier: "com.google.Chrome",
            webURL: "https://github.com/ZainLet/luum",
            preferences: preferences
        )

        XCTAssertTrue(ignored)
    }

    func testMigratesLegacyGoogleCalendarSnapshot() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let legacy = LegacyGoogleCalendarSnapshotFixture(
            clientID: "client-id",
            clientSecret: "client-secret",
            tokens: GoogleCalendarTokens(
                accessToken: "access",
                refreshToken: "refresh",
                idToken: nil,
                tokenType: "Bearer",
                scope: "calendar",
                expiresAt: now.addingTimeInterval(3600)
            ),
            profile: GoogleCalendarProfile(
                email: "team@luum.app",
                name: "Luum Team",
                pictureURL: nil
            ),
            agendaDay: now,
            agendaItems: [],
            lastSyncAt: now
        )

        let data = try JSONEncoder().encode(legacy)
        let snapshot = try JSONDecoder().decode(GoogleCalendarSnapshot.self, from: data)

        XCTAssertEqual(snapshot.clientID, "client-id")
        XCTAssertEqual(snapshot.connections.count, 1)
        XCTAssertEqual(snapshot.connections.first?.profile.email, "team@luum.app")
        XCTAssertEqual(snapshot.connections.first?.legacyTokens?.refreshToken, "refresh")
        XCTAssertEqual(snapshot.connections.first?.calendars.first?.id, "primary")
    }

    func testDecodesLegacyAgendaItemsWithoutAccountMetadata() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let legacy = LegacyAgendaItemFixture(
            id: "event-1",
            title: "Daily",
            location: nil,
            notes: nil,
            startDate: now,
            endDate: now.addingTimeInterval(1800),
            isAllDay: false,
            htmlLink: nil
        )

        let data = try JSONEncoder().encode(legacy)
        let item = try JSONDecoder().decode(CalendarAgendaItem.self, from: data)

        XCTAssertEqual(item.accountID, "legacy-account")
        XCTAssertEqual(item.calendarID, "primary")
        XCTAssertEqual(item.calendarTitle, "Principal")
    }
}

private struct LegacyGoogleCalendarSnapshotFixture: Encodable {
    let clientID: String
    let clientSecret: String
    let tokens: GoogleCalendarTokens
    let profile: GoogleCalendarProfile
    let agendaDay: Date
    let agendaItems: [CalendarAgendaItem]
    let lastSyncAt: Date
}

private struct LegacyAgendaItemFixture: Encodable {
    let id: String
    let title: String
    let location: String?
    let notes: String?
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let htmlLink: String?
}
#endif
