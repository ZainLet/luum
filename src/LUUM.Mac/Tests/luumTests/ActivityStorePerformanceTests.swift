import Foundation
import Observation

#if canImport(Testing)
import Testing
@testable import luum

@MainActor
@Test
func searchResultsRespectLimitAndPreferRecentSamples() throws {
    let tempDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("luum-search-\(UUID().uuidString)", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: tempDirectory)
    }

    let persistence = ActivityPersistence(directoryURL: tempDirectory)
    let baseDate = Date(timeIntervalSince1970: 1_800_000_000)
    let samples = (0 ..< 120).map { index in
        ActivitySample(
            startDate: baseDate.addingTimeInterval(TimeInterval(index * 60)),
            endDate: baseDate.addingTimeInterval(TimeInterval(index * 60 + 30)),
            applicationName: "TargetApp",
            bundleIdentifier: "app.luum.target",
            webURL: nil,
            webDomain: nil,
            pageTitle: "target sample \(index)",
            source: .nativeApp
        )
    }
    try persistence.save(samples: samples, retentionDays: 365)

    let store = ActivityStore(persistence: persistence)
    let results = store.searchResults(matching: "target", limit: 10)

    #expect(results.count == 10)
    #expect(results.first?.title == "target sample 119")
    #expect(results.last?.title == "target sample 110")
}

@MainActor
@Test
func cancelledPersistenceDebounceDoesNotFlushImmediately() async throws {
    let tempDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("luum-persistence-\(UUID().uuidString)", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: tempDirectory)
    }

    let persistence = ActivityPersistence(directoryURL: tempDirectory)
    let baseDate = Date()
    let sample = ActivitySample(
        startDate: baseDate.addingTimeInterval(-60),
        endDate: baseDate,
        applicationName: "Editor",
        bundleIdentifier: "app.luum.editor",
        webURL: nil,
        webDomain: nil,
        pageTitle: nil,
        source: .nativeApp
    )
    try persistence.save(samples: [sample], retentionDays: 365)

    let store = ActivityStore(
        persistence: persistence,
        activityPersistenceDebounce: .milliseconds(250)
    )

    store.updateActivityNote(sampleID: sample.id, note: "primeira")
    store.updateActivityNote(sampleID: sample.id, note: "segunda")

    try await Task.sleep(for: .milliseconds(80))
    #expect(persistence.load(retentionDays: 365).first?.note == nil)

    try await Task.sleep(for: .milliseconds(260))
    #expect(persistence.load(retentionDays: 365).first?.note == "segunda")
}

@MainActor
@Test
func persistenceFlushDoesNotReassignUnchangedSamples() async throws {
    let tempDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("luum-persistence-stable-\(UUID().uuidString)", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: tempDirectory)
    }

    let persistence = ActivityPersistence(directoryURL: tempDirectory)
    let baseDate = Date()
    let sample = ActivitySample(
        startDate: baseDate.addingTimeInterval(-60),
        endDate: baseDate,
        applicationName: "Editor",
        bundleIdentifier: "app.luum.editor",
        webURL: nil,
        webDomain: nil,
        pageTitle: nil,
        source: .nativeApp
    )
    try persistence.save(samples: [sample], retentionDays: 365)

    let store = ActivityStore(
        persistence: persistence,
        activityPersistenceDebounce: .milliseconds(80)
    )
    store.updateActivityNote(sampleID: sample.id, note: "nota")

    var samplesInvalidatedByFlush = false
    withObservationTracking {
        _ = store.samples
    } onChange: {
        samplesInvalidatedByFlush = true
    }

    try await Task.sleep(for: .milliseconds(140))

    #expect(samplesInvalidatedByFlush == false)
    #expect(persistence.load(retentionDays: 365).first?.note == "nota")
}

@Test
func reminderEvaluationThrottleSkipsOnlyRecentLiveExtensions() {
    let lastRequest = Date(timeIntervalSince1970: 1_800_000_000)

    #expect(ActivityStore.shouldSkipReminderEvaluation(
        force: false,
        lastRequestedAt: lastRequest,
        now: lastRequest.addingTimeInterval(12),
        minimumInterval: 30
    ))

    #expect(!ActivityStore.shouldSkipReminderEvaluation(
        force: false,
        lastRequestedAt: lastRequest,
        now: lastRequest.addingTimeInterval(31),
        minimumInterval: 30
    ))

    #expect(!ActivityStore.shouldSkipReminderEvaluation(
        force: true,
        lastRequestedAt: lastRequest,
        now: lastRequest.addingTimeInterval(12),
        minimumInterval: 30
    ))

    #expect(!ActivityStore.shouldSkipReminderEvaluation(
        force: false,
        lastRequestedAt: nil,
        now: lastRequest,
        minimumInterval: 30
    ))
}
#endif
