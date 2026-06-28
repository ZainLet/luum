import Foundation
import UserNotifications

#if canImport(Testing)
import Testing
@testable import luum

// MARK: - Mock UNUserNotificationCenter

private final class MockNotificationCenter: UNUserNotificationCenter {
    var addedRequests: [UNNotificationRequest] = []
    var authorizedStatus: UNAuthorizationStatus = .authorized
    var requestedAuthorization = false

    override func add(_ request: UNNotificationRequest) async throws {
        addedRequests.append(request)
    }

    override func notificationSettings() async -> UNNotificationSettings {
        let decoder = NSKeyedUnarchiver(forReadingWith: {
            let archiver = NSKeyedArchiver(requiringSecureCoding: false)
            // Return a real UNNotificationSettings with authorized status via subclass shim
            archiver.finishEncoding()
            return archiver.encodedData
        }())
        return await super.notificationSettings()
    }
}

// Simpler approach: use a protocol-based mock instead
private actor NotificationSpy {
    var addedIdentifiers: [String] = []

    func recordAdd(identifier: String) {
        addedIdentifiers.append(identifier)
    }
}

// MARK: - Helper factories

private func makeSample(
    applicationName: String = "Xcode",
    bundleIdentifier: String? = "com.apple.dt.Xcode",
    start: Date,
    duration: TimeInterval = 300
) -> ActivitySample {
    ActivitySample(
        startDate: start,
        endDate: start.addingTimeInterval(duration),
        applicationName: applicationName,
        bundleIdentifier: bundleIdentifier,
        webURL: nil,
        webDomain: nil,
        pageTitle: nil,
        source: .screen
    )
}

private func makePreferences(
    reminderProfiles: [ReminderProfile] = [],
    categoryRules: [CategoryRule] = ClassificationEngine.defaultRules
) -> MonitoringPreferencesSnapshot {
    MonitoringPreferencesSnapshot(
        categories: ActivityCategory.builtInCategories,
        categoryRules: categoryRules,
        ignoredApplications: [],
        ignoredDomains: [],
        reminderProfiles: reminderProfiles
    )
}

private func makeWorkReminder(
    thresholdMinutes: Int = 25,
    weekdays: [Int] = [1, 2, 3, 4, 5, 6, 7]
) -> ReminderProfile {
    ReminderProfile(
        title: "Pausa para trabalho",
        categoryID: "work",
        thresholdMinutes: thresholdMinutes,
        weekdays: weekdays,
        isEnabled: true,
        message: "Hora de uma pausa!"
    )
}

// MARK: - Tests

@MainActor
@Test
func reminderEngineDoesNotFireWhenStreakBelowThreshold() async {
    let engine = ReminderEngine()
    var firedMessage: String?
    engine.onReminderMessage = { firedMessage = $0 }

    let now = Date()
    // 20 minutos de trabalho, threshold é 25 minutos
    let samples = [makeSample(start: now.addingTimeInterval(-1200), duration: 1200)]
    let preferences = makePreferences(reminderProfiles: [makeWorkReminder(thresholdMinutes: 25)])
    let classifier = ClassificationEngine()

    await engine.evaluate(samples: samples, preferences: preferences, classifier: classifier)

    #expect(firedMessage == nil)
}

@MainActor
@Test
func reminderEngineFiresWhenStreakMeetsThreshold() async {
    let engine = ReminderEngine()
    var firedMessage: String?
    engine.onReminderMessage = { firedMessage = $0 }

    let now = Date()
    // 30 minutos de trabalho, threshold é 25 minutos
    let samples = [makeSample(start: now.addingTimeInterval(-1800), duration: 1800)]
    let preferences = makePreferences(reminderProfiles: [makeWorkReminder(thresholdMinutes: 25)])
    let classifier = ClassificationEngine()

    await engine.evaluate(samples: samples, preferences: preferences, classifier: classifier)

    #expect(firedMessage != nil)
}

@MainActor
@Test
func reminderEngineDoesNotFireTwiceForSameStreak() async {
    let engine = ReminderEngine()
    var fireCount = 0
    engine.onReminderMessage = { _ in fireCount += 1 }

    let now = Date()
    let samples = [makeSample(start: now.addingTimeInterval(-3600), duration: 3600)]
    let preferences = makePreferences(reminderProfiles: [makeWorkReminder(thresholdMinutes: 25)])
    let classifier = ClassificationEngine()

    await engine.evaluate(samples: samples, preferences: preferences, classifier: classifier)
    await engine.evaluate(samples: samples, preferences: preferences, classifier: classifier)

    #expect(fireCount == 1)
}

@MainActor
@Test
func reminderEngineSkipsReminderWhenCategoryDoesNotMatch() async {
    let engine = ReminderEngine()
    var firedMessage: String?
    engine.onReminderMessage = { firedMessage = $0 }

    let now = Date()
    // 30 minutos de entertainment, mas reminder é para work
    let samples = [makeSample(
        applicationName: "Spotify",
        bundleIdentifier: "com.spotify.client",
        start: now.addingTimeInterval(-1800),
        duration: 1800
    )]
    let preferences = makePreferences(reminderProfiles: [makeWorkReminder(thresholdMinutes: 1)])
    let classifier = ClassificationEngine()

    await engine.evaluate(samples: samples, preferences: preferences, classifier: classifier)

    #expect(firedMessage == nil)
}

@MainActor
@Test
func reminderEngineSkipsDisabledReminders() async {
    let engine = ReminderEngine()
    var firedMessage: String?
    engine.onReminderMessage = { firedMessage = $0 }

    let now = Date()
    let samples = [makeSample(start: now.addingTimeInterval(-3600), duration: 3600)]

    let disabledReminder = ReminderProfile(
        title: "Desabilitado",
        categoryID: "work",
        thresholdMinutes: 1,
        weekdays: [1, 2, 3, 4, 5, 6, 7],
        isEnabled: false,
        message: "Nunca deve disparar"
    )
    let preferences = makePreferences(reminderProfiles: [disabledReminder])
    let classifier = ClassificationEngine()

    await engine.evaluate(samples: samples, preferences: preferences, classifier: classifier)

    #expect(firedMessage == nil)
}

@MainActor
@Test
func reminderEngineStreakBreaksOnCategoryChange() async {
    let engine = ReminderEngine()
    var firedMessage: String?
    engine.onReminderMessage = { firedMessage = $0 }

    let now = Date()
    // 20 min work, depois 20 min entertainment, depois mais 20 min work
    // A streak de work corrente é só 20 minutos (threshold 25), não deve disparar
    let samples = [
        makeSample(applicationName: "Xcode", bundleIdentifier: "com.apple.dt.Xcode",
                   start: now.addingTimeInterval(-3600), duration: 1200),
        makeSample(applicationName: "Spotify", bundleIdentifier: "com.spotify.client",
                   start: now.addingTimeInterval(-2400), duration: 1200),
        makeSample(applicationName: "Xcode", bundleIdentifier: "com.apple.dt.Xcode",
                   start: now.addingTimeInterval(-1200), duration: 1200)
    ]
    let preferences = makePreferences(reminderProfiles: [makeWorkReminder(thresholdMinutes: 25)])
    let classifier = ClassificationEngine()

    await engine.evaluate(samples: samples, preferences: preferences, classifier: classifier)

    #expect(firedMessage == nil)
}

@MainActor
@Test
func reminderEngineToleratesTolerableGapsBetweenSamples() async {
    let engine = ReminderEngine(streakGapTolerance: 90)
    var firedMessage: String?
    engine.onReminderMessage = { firedMessage = $0 }

    let now = Date()
    // Dois blocos de 15 min com gap de 85s (dentro do tolerance de 90s)
    // Streak total = 30 min ≥ threshold 25 → deve disparar
    let sample1 = ActivitySample(
        startDate: now.addingTimeInterval(-1885),
        endDate: now.addingTimeInterval(-1000),
        applicationName: "Xcode", bundleIdentifier: "com.apple.dt.Xcode",
        webURL: nil, webDomain: nil, pageTitle: nil, source: .screen
    )
    let sample2 = ActivitySample(
        startDate: now.addingTimeInterval(-915),
        endDate: now.addingTimeInterval(-15),
        applicationName: "Xcode", bundleIdentifier: "com.apple.dt.Xcode",
        webURL: nil, webDomain: nil, pageTitle: nil, source: .screen
    )

    let preferences = makePreferences(reminderProfiles: [makeWorkReminder(thresholdMinutes: 25)])
    let classifier = ClassificationEngine()

    await engine.evaluate(samples: [sample1, sample2], preferences: preferences, classifier: classifier)

    #expect(firedMessage != nil)
}

@MainActor
@Test
func continuousStreakReturnsDurationForSingleSample() async {
    let engine = ReminderEngine()
    var firedMessage: String?
    engine.onReminderMessage = { firedMessage = $0 }

    let now = Date()
    // Amostra única de exatamente 30 min → streak = 30 min = threshold 30 min → dispara
    let samples = [makeSample(start: now.addingTimeInterval(-1800), duration: 1800)]
    let preferences = makePreferences(reminderProfiles: [makeWorkReminder(thresholdMinutes: 30)])
    let classifier = ClassificationEngine()

    await engine.evaluate(samples: samples, preferences: preferences, classifier: classifier)

    #expect(firedMessage != nil)
}

@MainActor
@Test
func evaluateFiresAfterNewStreakStarted() async {
    let engine = ReminderEngine()
    var fireCount = 0
    engine.onReminderMessage = { _ in fireCount += 1 }

    let classifier = ClassificationEngine()
    let preferences = makePreferences(reminderProfiles: [makeWorkReminder(thresholdMinutes: 25)])

    // Primeira streak: 60 min → dispara; lastDeliveredAt é registrado com Date() ≈ agora
    let now = Date()
    let firstSamples = [makeSample(start: now.addingTimeInterval(-3600), duration: 3600)]
    await engine.evaluate(samples: firstSamples, preferences: preferences, classifier: classifier)
    #expect(fireCount == 1)

    // Nova streak com startDate posterior à entrega → throttle não bloqueia → dispara de novo
    let afterDelivery = Date().addingTimeInterval(1)
    let secondSamples = [makeSample(start: afterDelivery, duration: 1800)]
    await engine.evaluate(samples: secondSamples, preferences: preferences, classifier: classifier)
    #expect(fireCount == 2)
}

@MainActor
@Test
func reminderEngineBreaksStreakOnGapAboveTolerance() async {
    let engine = ReminderEngine(streakGapTolerance: 90)
    var firedMessage: String?
    engine.onReminderMessage = { firedMessage = $0 }

    let now = Date()
    // Dois blocos de 20 min com gap de 120s (acima do tolerance de 90s)
    // Streak corrente = 20 min < threshold 25 → não deve disparar
    let sample1 = ActivitySample(
        startDate: now.addingTimeInterval(-2520),
        endDate: now.addingTimeInterval(-1320),
        applicationName: "Xcode", bundleIdentifier: "com.apple.dt.Xcode",
        webURL: nil, webDomain: nil, pageTitle: nil, source: .screen
    )
    let sample2 = ActivitySample(
        startDate: now.addingTimeInterval(-1200),
        endDate: now,
        applicationName: "Xcode", bundleIdentifier: "com.apple.dt.Xcode",
        webURL: nil, webDomain: nil, pageTitle: nil, source: .screen
    )

    let preferences = makePreferences(reminderProfiles: [makeWorkReminder(thresholdMinutes: 25)])
    let classifier = ClassificationEngine()

    await engine.evaluate(samples: [sample1, sample2], preferences: preferences, classifier: classifier)

    #expect(firedMessage == nil)
}

#endif
