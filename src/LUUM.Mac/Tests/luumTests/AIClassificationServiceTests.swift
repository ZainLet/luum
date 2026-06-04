import Foundation

#if canImport(Testing)
import Testing
@testable import luum

@Test
func parsesGeminiJSONClassificationResponse() throws {
    let text = """
    ```json
    {"categoryID":"work","confidence":0.84,"reason":"App usado para desenvolvimento."}
    ```
    """

    let result = try #require(AIClassificationService.result(from: text))

    #expect(result.categoryID == "work")
    #expect(result.confidence == 0.84)
    #expect(result.reason == "App usado para desenvolvimento.")
}

@Test
func normalizesAIClassificationSettingsSafely() {
    let settings = AIClassificationSettings(
        isEnabled: true,
        providerName: " ",
        endpointURL: "https://generativelanguage.googleapis.com/v1beta/",
        model: " ",
        minimumConfidence: 2
    ).normalized()

    #expect(settings.providerName == "Gemini")
    #expect(settings.endpointURL == "https://generativelanguage.googleapis.com/v1beta")
    #expect(settings.model == "gemini-2.5-flash")
    #expect(settings.minimumConfidence == 0.99)
}
#elseif canImport(XCTest)
import XCTest
@testable import luum

final class AIClassificationServiceTests: XCTestCase {
    func testParsesGeminiJSONClassificationResponse() throws {
        let text = """
        ```json
        {"categoryID":"work","confidence":0.84,"reason":"App usado para desenvolvimento."}
        ```
        """

        let result = try XCTUnwrap(AIClassificationService.result(from: text))

        XCTAssertEqual(result.categoryID, "work")
        XCTAssertEqual(result.confidence, 0.84)
        XCTAssertEqual(result.reason, "App usado para desenvolvimento.")
    }

    func testNormalizesAIClassificationSettingsSafely() {
        let settings = AIClassificationSettings(
            isEnabled: true,
            providerName: " ",
            endpointURL: "https://generativelanguage.googleapis.com/v1beta/",
            model: " ",
            minimumConfidence: 2
        ).normalized()

        XCTAssertEqual(settings.providerName, "Gemini")
        XCTAssertEqual(settings.endpointURL, "https://generativelanguage.googleapis.com/v1beta")
        XCTAssertEqual(settings.model, "gemini-2.5-flash")
        XCTAssertEqual(settings.minimumConfidence, 0.99)
    }
}
#endif
