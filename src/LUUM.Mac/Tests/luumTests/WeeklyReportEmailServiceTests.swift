import Foundation

#if canImport(Testing)
import Testing
@testable import luum

@Test
func weeklyReportEmailServiceSendsReportToOfficialBackend() async throws {
    let session = URLSession.weeklyReportMocking([
        WeeklyReportMockResponse(
            url: "https://luum-app.vercel.app/api/reports/weekly-email",
            statusCode: 200,
            body: #"{"ok":true,"emailed":true,"emailID":"email_123","fileName":"luum-weekly-report-2026-06-08.pdf"}"#
        )
    ])
    let service = WeeklyReportEmailService(session: session)

    let response = try await service.send(
        firebaseToken: "firebase-token",
        email: "user@luum.app",
        report: weeklyReportPayloadForTesting()
    )

    #expect(response.ok)
    #expect(response.emailed)
    #expect(response.emailID == "email_123")
    #expect(response.fileName == "luum-weekly-report-2026-06-08.pdf")

    let request = try #require(WeeklyReportMockURLProtocol.observedRequests.first)
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer firebase-token")
    #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
    let body = try #require(request.httpBody)
    let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
    #expect(json["email"] as? String == "user@luum.app")
    #expect((json["report"] as? [String: Any])?["startDate"] as? String == "2026-06-08")
}

@Test
func weeklyReportEmailServiceRejectsNonOfficialBackendBeforeSendingToken() async throws {
    let session = URLSession.weeklyReportMocking([])
    let service = WeeklyReportEmailService(session: session)

    do {
        _ = try await service.send(
            baseURL: "https://example.com",
            firebaseToken: "firebase-token",
            email: "user@luum.app",
            report: weeklyReportPayloadForTesting()
        )
        Issue.record("Endpoint externo nao deveria receber token Firebase.")
    } catch WeeklyReportEmailServiceError.invalidEndpoint {
        #expect(WeeklyReportMockURLProtocol.observedRequests.isEmpty)
    } catch {
        Issue.record("Erro inesperado: \(error)")
    }
}

@Test
func weeklyReportEmailServiceSurfacesAPIErrorMessage() async throws {
    let session = URLSession.weeklyReportMocking([
        WeeklyReportMockResponse(
            url: "https://luum-app.vercel.app/api/reports/weekly-email",
            statusCode: 403,
            body: #"{"error":"Relatórios por email exigem o plano Profissional ou maior"}"#
        )
    ])
    let service = WeeklyReportEmailService(session: session)

    do {
        _ = try await service.send(
            firebaseToken: "firebase-token",
            email: "user@luum.app",
            report: weeklyReportPayloadForTesting()
        )
        Issue.record("Erro 403 deveria ser repassado para a UI.")
    } catch WeeklyReportEmailServiceError.apiError(let message) {
        #expect(message.contains("Profissional"))
    } catch {
        Issue.record("Erro inesperado: \(error)")
    }
}

private func weeklyReportPayloadForTesting() -> WeeklyReportEmailPayload {
    WeeklyReportEmailPayload(
        startDate: "2026-06-08",
        endDate: "2026-06-14",
        totalTrackedTime: 18_000,
        averageDailyTrackedTime: 3_600,
        contextSwitches: 42,
        focusTime: 10_800,
        distractionTime: 1_800,
        topCategories: [WeeklyReportEmailBreakdown(label: "Trabalho", duration: 12_000)],
        topApps: [WeeklyReportEmailBreakdown(label: "Xcode", duration: 7_200)],
        topSites: [WeeklyReportEmailBreakdown(label: "github.com", duration: 2_400)],
        highlights: ["Boa semana de foco"]
    )
}

private struct WeeklyReportMockResponse: Sendable {
    let url: String
    let statusCode: Int
    let body: String
}

private final class WeeklyReportMockURLProtocol: URLProtocol, @unchecked Sendable {
    private nonisolated(unsafe) static let storageQueue = DispatchQueue(label: "luum.weekly-report-email-test-url-protocol")
    private nonisolated(unsafe) static var responses: [WeeklyReportMockResponse] = []
    private nonisolated(unsafe) static var storedObservedRequests: [URLRequest] = []

    static var observedRequests: [URLRequest] {
        storageQueue.sync { storedObservedRequests }
    }

    static func configure(responses: [WeeklyReportMockResponse]) {
        storageQueue.sync {
            self.responses = responses
            self.storedObservedRequests = []
        }
    }

    private static func appendObservedRequest(_ request: URLRequest) {
        storageQueue.sync {
            storedObservedRequests.append(request)
        }
    }

    private static func removeResponse(for url: String) -> WeeklyReportMockResponse? {
        storageQueue.sync {
            guard let index = responses.firstIndex(where: { $0.url == url }) else { return nil }
            return responses.remove(at: index)
        }
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.appendObservedRequest(request)
        guard let url = request.url?.absoluteString else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        guard let response = Self.removeResponse(for: url) else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }

        let data = Data(response.body.utf8)
        guard
            let requestURL = request.url,
            let httpResponse = HTTPURLResponse(
            url: requestURL,
            statusCode: response.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
            )
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private extension URLSession {
    static func weeklyReportMocking(_ responses: [WeeklyReportMockResponse]) -> URLSession {
        WeeklyReportMockURLProtocol.configure(responses: responses)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [WeeklyReportMockURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}
#endif
