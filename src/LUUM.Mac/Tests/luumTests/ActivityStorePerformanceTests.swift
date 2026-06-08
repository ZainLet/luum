import Foundation

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
#endif
