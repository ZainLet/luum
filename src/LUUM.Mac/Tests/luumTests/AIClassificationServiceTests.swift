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
        endpointURL: " ",
        model: " ",
        minimumConfidence: 2
    ).normalized()

    #expect(settings.providerName == "Gemini")
    #expect(settings.endpointURL == "\(FirebaseAuthService.defaultBaseURL)/api/ai/classify")
    #expect(settings.model == "gemini-2.5-flash")
    #expect(settings.minimumConfidence == 0.99)
}

@Test
func classifiesThroughLuumBackendWithFirebaseToken() async throws {
    let session = URLSession.aiMocking([
        AIClassifyMockResponse(
            url: "https://luum-app.vercel.app/api/ai/classify",
            requiredAuthorization: "Bearer firebase-token",
            statusCode: 200,
            body: #"{"categoryID":"work","confidence":0.9,"reason":"Ferramenta profissional."}"#
        )
    ])
    let service = AIClassificationService(session: session)

    let result = try await service.classify(
        request: AIClassificationRequest(
            kind: .application,
            label: "Figma",
            secondaryLabel: "com.figma.Desktop",
            currentCategory: nil,
            categories: ActivityCategory.builtInCategories
        ),
        settings: AIClassificationSettings.default.normalized().withEnabledForTesting(),
        apiKey: nil,
        firebaseToken: "firebase-token"
    )

    #expect(result.categoryID == "work")
    #expect(result.confidence == 0.9)
}

private extension AIClassificationSettings {
    func withEnabledForTesting() -> AIClassificationSettings {
        var copy = self
        copy.isEnabled = true
        return copy
    }
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
            endpointURL: " ",
            model: " ",
            minimumConfidence: 2
        ).normalized()

        XCTAssertEqual(settings.providerName, "Gemini")
        XCTAssertEqual(settings.endpointURL, "\(FirebaseAuthService.defaultBaseURL)/api/ai/classify")
        XCTAssertEqual(settings.model, "gemini-2.5-flash")
        XCTAssertEqual(settings.minimumConfidence, 0.99)
    }

    func testClassifiesThroughLuumBackendWithFirebaseToken() async throws {
        let session = URLSession.aiMocking([
            AIClassifyMockResponse(
                url: "https://luum-app.vercel.app/api/ai/classify",
                requiredAuthorization: "Bearer firebase-token",
                statusCode: 200,
                body: #"{"categoryID":"work","confidence":0.9,"reason":"Ferramenta profissional."}"#
            )
        ])
        let service = AIClassificationService(session: session)

        let result = try await service.classify(
            request: AIClassificationRequest(
                kind: .application,
                label: "Figma",
                secondaryLabel: "com.figma.Desktop",
                currentCategory: nil,
                categories: ActivityCategory.builtInCategories
            ),
            settings: AIClassificationSettings.default.normalized().withEnabledForTesting(),
            apiKey: nil,
            firebaseToken: "firebase-token"
        )

        XCTAssertEqual(result.categoryID, "work")
        XCTAssertEqual(result.confidence, 0.9)
    }
}

private extension AIClassificationSettings {
    func withEnabledForTesting() -> AIClassificationSettings {
        var copy = self
        copy.isEnabled = true
        return copy
    }
}
#endif

private struct AIClassifyMockResponse: Sendable {
    let url: String
    let requiredAuthorization: String?
    let statusCode: Int
    let body: String
}

private final class AIClassifyMockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var responses: [AIClassifyMockResponse] = []

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url?.absoluteString else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        guard let index = Self.responses.firstIndex(where: { $0.url == url }) else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }

        let response = Self.responses.remove(at: index)
        if let requiredAuthorization = response.requiredAuthorization,
           request.value(forHTTPHeaderField: "Authorization") != requiredAuthorization {
            client?.urlProtocol(self, didFailWithError: URLError(.userAuthenticationRequired))
            return
        }

        let data = Data(response.body.utf8)
        let httpResponse = HTTPURLResponse(
            url: request.url!,
            statusCode: response.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private extension URLSession {
    static func aiMocking(_ responses: [AIClassifyMockResponse]) -> URLSession {
        AIClassifyMockURLProtocol.responses = responses
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AIClassifyMockURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}
