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
}
#endif
