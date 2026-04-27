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
}
#endif
