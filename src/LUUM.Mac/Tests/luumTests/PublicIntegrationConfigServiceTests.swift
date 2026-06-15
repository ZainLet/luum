import Foundation

#if canImport(Testing)
import Testing
@testable import luum

@Test
func publicIntegrationConfigServiceLoadsOnlyOfficialBootstrapConfig() async throws {
    let session = URLSession.publicIntegrationConfigMocking([
        PublicIntegrationConfigMockResponse(
            url: "https://luum-app.vercel.app/api/public/integrations",
            statusCode: 200,
            body: """
            {
              "googleCalendar": {
                "configured": true,
                "clientID": "google-client.apps.googleusercontent.com"
              },
              "outlookCalendar": {
                "configured": false,
                "clientID": null
              },
              "managedOAuth": {
                "googleCalendar": true,
                "outlookCalendar": false,
                "notion": true,
                "clickUp": false,
                "linear": false,
                "zapier": false
              }
            }
            """
        )
    ])
    let service = PublicIntegrationConfigService(session: session)

    let config = try await service.fetch()

    #expect(config.googleCalendar.configured)
    #expect(config.googleCalendar.clientID == "google-client.apps.googleusercontent.com")
    #expect(config.managedOAuth.googleCalendar)
    #expect(config.managedOAuth.notion)
    #expect(!config.managedOAuth.linear)
    let request = try #require(PublicIntegrationConfigMockURLProtocol.observedRequests.first)
    #expect(request.timeoutInterval == 8)
    #expect(request.cachePolicy == .reloadIgnoringLocalAndRemoteCacheData)
}

@Test
func publicIntegrationConfigServiceRejectsNonOfficialBackendBeforeRequest() async throws {
    let session = URLSession.publicIntegrationConfigMocking([])
    let service = PublicIntegrationConfigService(session: session)

    do {
        _ = try await service.fetch(baseURL: "https://example.com")
        Issue.record("Endpoint externo nao deveria ser consultado para bootstrap de integracoes.")
    } catch PublicIntegrationConfigError.invalidBaseURL {
        #expect(PublicIntegrationConfigMockURLProtocol.observedRequests.isEmpty)
    } catch {
        Issue.record("Erro inesperado: \(error)")
    }
}

@Test
func publicIntegrationConfigServiceExplainsMissingRoute() async throws {
    let session = URLSession.publicIntegrationConfigMocking([
        PublicIntegrationConfigMockResponse(
            url: "https://luum-app.vercel.app/api/public/integrations",
            statusCode: 404,
            body: #"<!doctype html><title>404</title>"#
        )
    ])
    let service = PublicIntegrationConfigService(session: session)

    do {
        _ = try await service.fetch()
        Issue.record("404 deveria explicar deploy/rota ausente.")
    } catch PublicIntegrationConfigError.routeMissing {
        #expect(PublicIntegrationConfigError.routeMissing.localizedDescription.contains("/api/public/integrations"))
    } catch {
        Issue.record("Erro inesperado: \(error)")
    }
}

@Test
func publicIntegrationConfigServiceReportsTemporaryBackendStatus() async throws {
    let session = URLSession.publicIntegrationConfigMocking([
        PublicIntegrationConfigMockResponse(
            url: "https://luum-app.vercel.app/api/public/integrations",
            statusCode: 503,
            body: #"{"error":"temporarily unavailable"}"#
        )
    ])
    let service = PublicIntegrationConfigService(session: session)

    do {
        _ = try await service.fetch()
        Issue.record("Status 503 deveria virar erro temporario claro.")
    } catch PublicIntegrationConfigError.unavailable(503) {
        #expect(PublicIntegrationConfigError.unavailable(503).localizedDescription.contains("HTTP 503"))
    } catch {
        Issue.record("Erro inesperado: \(error)")
    }
}
#elseif canImport(XCTest)
import XCTest
@testable import luum

final class PublicIntegrationConfigServiceTests: XCTestCase {
    func testPublicIntegrationConfigServiceLoadsOnlyOfficialBootstrapConfig() async throws {
        let session = URLSession.publicIntegrationConfigMocking([
            PublicIntegrationConfigMockResponse(
                url: "https://luum-app.vercel.app/api/public/integrations",
                statusCode: 200,
                body: """
                {
                  "googleCalendar": {
                    "configured": true,
                    "clientID": "google-client.apps.googleusercontent.com"
                  },
                  "outlookCalendar": {
                    "configured": false,
                    "clientID": null
                  },
                  "managedOAuth": {
                    "googleCalendar": true,
                    "outlookCalendar": false,
                    "notion": true,
                    "clickUp": false,
                    "linear": false,
                    "zapier": false
                  }
                }
                """
            )
        ])
        let service = PublicIntegrationConfigService(session: session)

        let config = try await service.fetch()

        XCTAssertTrue(config.googleCalendar.configured)
        XCTAssertEqual(config.googleCalendar.clientID, "google-client.apps.googleusercontent.com")
        XCTAssertTrue(config.managedOAuth.googleCalendar)
        XCTAssertTrue(config.managedOAuth.notion)
        XCTAssertFalse(config.managedOAuth.linear)
        let request = try XCTUnwrap(PublicIntegrationConfigMockURLProtocol.observedRequests.first)
        XCTAssertEqual(request.timeoutInterval, 8)
        XCTAssertEqual(request.cachePolicy, .reloadIgnoringLocalAndRemoteCacheData)
    }

    func testPublicIntegrationConfigServiceRejectsNonOfficialBackendBeforeRequest() async throws {
        let session = URLSession.publicIntegrationConfigMocking([])
        let service = PublicIntegrationConfigService(session: session)

        do {
            _ = try await service.fetch(baseURL: "https://example.com")
            XCTFail("Endpoint externo nao deveria ser consultado para bootstrap de integracoes.")
        } catch PublicIntegrationConfigError.invalidBaseURL {
            XCTAssertTrue(PublicIntegrationConfigMockURLProtocol.observedRequests.isEmpty)
        } catch {
            XCTFail("Erro inesperado: \(error)")
        }
    }

    func testPublicIntegrationConfigServiceExplainsMissingRoute() async throws {
        let session = URLSession.publicIntegrationConfigMocking([
            PublicIntegrationConfigMockResponse(
                url: "https://luum-app.vercel.app/api/public/integrations",
                statusCode: 404,
                body: #"<!doctype html><title>404</title>"#
            )
        ])
        let service = PublicIntegrationConfigService(session: session)

        do {
            _ = try await service.fetch()
            XCTFail("404 deveria explicar deploy/rota ausente.")
        } catch PublicIntegrationConfigError.routeMissing {
            XCTAssertTrue(PublicIntegrationConfigError.routeMissing.localizedDescription.contains("/api/public/integrations"))
        } catch {
            XCTFail("Erro inesperado: \(error)")
        }
    }

    func testPublicIntegrationConfigServiceReportsTemporaryBackendStatus() async throws {
        let session = URLSession.publicIntegrationConfigMocking([
            PublicIntegrationConfigMockResponse(
                url: "https://luum-app.vercel.app/api/public/integrations",
                statusCode: 503,
                body: #"{"error":"temporarily unavailable"}"#
            )
        ])
        let service = PublicIntegrationConfigService(session: session)

        do {
            _ = try await service.fetch()
            XCTFail("Status 503 deveria virar erro temporario claro.")
        } catch PublicIntegrationConfigError.unavailable(503) {
            XCTAssertTrue(PublicIntegrationConfigError.unavailable(503).localizedDescription.contains("HTTP 503"))
        } catch {
            XCTFail("Erro inesperado: \(error)")
        }
    }
}
#endif

private struct PublicIntegrationConfigMockResponse: Sendable {
    let url: String
    let statusCode: Int
    let body: String
}

private final class PublicIntegrationConfigMockURLProtocol: URLProtocol, @unchecked Sendable {
    private nonisolated(unsafe) static var responses: [PublicIntegrationConfigMockResponse] = []
    private(set) nonisolated(unsafe) static var observedRequests: [URLRequest] = []

    static func configure(responses: [PublicIntegrationConfigMockResponse]) {
        self.responses = responses
        observedRequests = []
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.observedRequests.append(request)
        guard let url = request.url?.absoluteString,
              let response = Self.responses.first(where: { $0.url == url }),
              let http = HTTPURLResponse(
                url: request.url!,
                statusCode: response.statusCode,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
              )
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        client?.urlProtocol(self, didReceive: http, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(response.body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private extension URLSession {
    static func publicIntegrationConfigMocking(_ responses: [PublicIntegrationConfigMockResponse]) -> URLSession {
        PublicIntegrationConfigMockURLProtocol.configure(responses: responses)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [PublicIntegrationConfigMockURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}
