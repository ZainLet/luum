import Foundation

#if canImport(Testing)
import Testing
@testable import luum

@Test
func authCallbackUsesUIDFromFirebaseToken() throws {
    let token = makeFirebaseToken(uid: "firebase-user", email: "user@luum.app")
    let callback = try #require(URL(string: "luum://auth?token=\(token)&uid=firebase-user"))

    let session = try FirebaseAuthService().session(from: callback)

    #expect(session.uid == "firebase-user")
    #expect(session.email == "user@luum.app")
    #expect(session.isLocked)
}

@Test
func authCallbackRejectsUIDDifferentFromFirebaseToken() throws {
    let token = makeFirebaseToken(uid: "firebase-user", email: "user@luum.app")
    let callback = try #require(URL(string: "luum://auth?token=\(token)&uid=another-user"))

    do {
        _ = try FirebaseAuthService().session(from: callback)
        Issue.record("Callback com UID divergente deveria ser rejeitado.")
    } catch FirebaseAuthServiceError.invalidToken {
        // Esperado: o servidor ainda valida a assinatura antes de liberar a sessão.
    } catch {
        Issue.record("Erro inesperado: \(error)")
    }
}

@Test
func authCallbackRejectsTokenFromAnotherFirebaseProject() throws {
    let token = makeFirebaseToken(
        uid: "firebase-user",
        email: "user@luum.app",
        audience: "other-project",
        issuer: "https://securetoken.google.com/other-project"
    )
    let callback = try #require(URL(string: "luum://auth?token=\(token)&uid=firebase-user"))

    do {
        _ = try FirebaseAuthService().session(from: callback)
        Issue.record("Callback de outro projeto Firebase deveria ser rejeitado localmente.")
    } catch FirebaseAuthServiceError.invalidToken {
        // Esperado: o app só aceita tokens emitidos para o projeto oficial luum-app.
    } catch {
        Issue.record("Erro inesperado: \(error)")
    }
}

@Test
func authCallbackRejectsTokenWithWrongIssuer() throws {
    let token = makeFirebaseToken(
        uid: "firebase-user",
        email: "user@luum.app",
        issuer: "https://securetoken.google.com/other-project"
    )
    let callback = try #require(URL(string: "luum://auth?token=\(token)&uid=firebase-user"))

    do {
        _ = try FirebaseAuthService().session(from: callback)
        Issue.record("Callback com issuer Firebase divergente deveria ser rejeitado.")
    } catch FirebaseAuthServiceError.invalidToken {
        // Esperado.
    } catch {
        Issue.record("Erro inesperado: \(error)")
    }
}

@Test
func authCallbackRequiresFirebaseToken() throws {
    let callback = try #require(URL(string: "luum://auth?uid=firebase-user"))

    do {
        _ = try FirebaseAuthService().session(from: callback)
        Issue.record("Callback sem token Firebase deveria ser rejeitado.")
    } catch FirebaseAuthServiceError.missingToken {
        // Esperado: o app nunca libera login por UID local sem token Firebase.
    } catch {
        Issue.record("Erro inesperado: \(error)")
    }
}

@Test
func officialBackendRejectsLocalAndExternalOverrides() {
    #expect(FirebaseAuthService.officialBackendURL(from: FirebaseAuthService.defaultBaseURL)?.absoluteString == FirebaseAuthService.defaultBaseURL)
    #expect(FirebaseAuthService.officialBackendURL(from: "http://localhost:5000") == nil)
    #expect(FirebaseAuthService.officialBackendURL(from: "https://example.com") == nil)
}

@Test
func verifiedSessionRejectsNonOfficialStatusEndpointBeforeSendingToken() async throws {
    let session = URLSession.mocking([
        MockResponse(
            url: "https://example.com/api/auth/status",
            statusCode: 200,
            body: #"{"locked":false,"plan":"negocios","trial":false}"#
        )
    ])
    let service = FirebaseAuthService(statusBaseURL: "https://example.com", session: session)

    do {
        _ = try await service.verifiedSession(makeAuthSession(lastVerifiedAt: nil))
        Issue.record("Endpoint externo nao deveria receber token Firebase.")
    } catch FirebaseAuthServiceError.invalidStatusEndpoint {
        #expect(MockURLProtocol.responses.count == 1)
    } catch {
        Issue.record("Erro inesperado: \(error)")
    }
}

@Test
func authErrorClassifiesExplicitRejectionsSeparatelyFromTemporaryFailures() {
    #expect(FirebaseAuthServiceError.statusRejected("HTTP 401").isExplicitAuthRejection)
    #expect(FirebaseAuthServiceError.statusRejected("HTTP 403").isExplicitAuthRejection)
    #expect(FirebaseAuthServiceError.statusRejected("refresh HTTP 400").isExplicitAuthRejection)
    #expect(!FirebaseAuthServiceError.statusRejected("HTTP 500").isExplicitAuthRejection)
    #expect(!FirebaseAuthServiceError.statusRejected("refresh HTTP 500").isExplicitAuthRejection)
    #expect(!FirebaseAuthServiceError.invalidStatusEndpoint.isExplicitAuthRejection)
}

@Test
func localSessionLocksWithoutRecentServerVerification() {
    let verifiedRecently = makeAuthSession(lastVerifiedAt: Date().addingTimeInterval(-60))
    let staleVerification = makeAuthSession(lastVerifiedAt: Date().addingTimeInterval(-(LuumAuthSession.offlineGracePeriod + 60)))
    let neverVerified = makeAuthSession(lastVerifiedAt: nil)

    #expect(!verifiedRecently.isLocked)
    #expect(staleVerification.isLocked)
    #expect(neverVerified.isLocked)
    #expect(staleVerification.lockExplanation?.contains("validacao local expirou") == true)
    #expect(neverVerified.lockExplanation?.contains("Valide seu plano") == true)
}

@Test
func cancelingSessionLocksAfterPaidPeriodEnds() {
    var current = makeAuthSession(lastVerifiedAt: Date().addingTimeInterval(-60))
    current.subscriptionStatus = "canceling"
    current.expiresAt = Date().addingTimeInterval(3600)

    var expired = current
    expired.expiresAt = Date().addingTimeInterval(-60)

    #expect(!current.isLocked)
    #expect(expired.isLocked)
    #expect(expired.lockExplanation?.contains("periodo de acesso terminou") == true)
}

@Test
func verifiedSessionAppliesActivePlanFromStatusEndpoint() async throws {
    let session = URLSession.mocking([
        MockResponse(
            url: "https://luum-app.vercel.app/api/auth/status",
            statusCode: 200,
            body: #"{"locked":false,"plan":"negocios","trial":false,"expiresAt":1780499999000,"daysRemaining":30}"#
        )
    ])
    let service = FirebaseAuthService(session: session)

    let verified = try await service.verifiedSession(makeAuthSession(lastVerifiedAt: nil))

    #expect(verified.plan == .negocios)
    #expect(verified.subscriptionStatus == "active")
    #expect(verified.lockedReason == nil)
    #expect(verified.lastVerifiedAt != nil)
    #expect(!verified.isLocked)
}

@Test
func verifiedSessionSendsInstallationDeviceIDToOfficialBackend() async throws {
    let session = URLSession.mocking([
        MockResponse(
            url: "https://luum-app.vercel.app/api/auth/status",
            statusCode: 200,
            body: #"{"locked":false,"plan":"profissional","trial":false,"expiresAt":1780499999000}"#
        )
    ])
    let service = FirebaseAuthService(session: session)

    _ = try await service.verifiedSession(makeAuthSession(lastVerifiedAt: nil), deviceID: "device-abc")

    let request = try #require(MockURLProtocol.observedRequests.first)
    #expect(request.value(forHTTPHeaderField: "X-Luum-Device-ID") == "device-abc")
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer token")
}

@Test
func verifiedSessionPreservesCancelingSubscriptionState() async throws {
    let session = URLSession.mocking([
        MockResponse(
            url: "https://luum-app.vercel.app/api/auth/status",
            statusCode: 200,
            body: #"{"locked":false,"plan":"profissional","trial":false,"canceling":true,"expiresAt":1780499999000}"#
        )
    ])
    let service = FirebaseAuthService(session: session)

    let verified = try await service.verifiedSession(makeAuthSession(lastVerifiedAt: nil))

    #expect(verified.plan == .profissional)
    #expect(verified.subscriptionStatus == "canceling")
    #expect(verified.lockedReason == nil)
    #expect(!verified.isLocked)
}

@Test
func verifiedSessionUsesBackendTrialEnd() async throws {
    let trialEnd = 1_780_499_999_000.0
    let session = URLSession.mocking([
        MockResponse(
            url: "https://luum-app.vercel.app/api/auth/status",
            statusCode: 200,
            body: #"{"locked":false,"plan":"essencial","trial":true,"trialEndsAt":1780499999000,"daysRemaining":3}"#
        )
    ])
    let service = FirebaseAuthService(session: session)

    let verified = try await service.verifiedSession(makeAuthSession(lastVerifiedAt: nil))

    #expect(verified.plan == .essencial)
    #expect(verified.subscriptionStatus == "trial")
    #expect(verified.trialEndsAt == Date(timeIntervalSince1970: trialEnd / 1000))
    #expect(verified.lockedReason == nil)
    #expect(!verified.isLocked)
}

@Test
func verifiedSessionRefreshesFirebaseTokenAfterUnauthorizedStatus() async throws {
    let session = URLSession.mocking([
        MockResponse(
            url: "https://luum-app.vercel.app/api/auth/status",
            statusCode: 401,
            body: #"{"error":"Token inválido ou expirado"}"#
        ),
        MockResponse(
            url: "https://securetoken.googleapis.com/v1/token?key=\(FirebaseAuthService.firebaseAPIKey)",
            statusCode: 200,
            body: #"{"id_token":"fresh-token","refresh_token":"fresh-refresh","expires_in":"3600"}"#
        ),
        MockResponse(
            url: "https://luum-app.vercel.app/api/auth/status",
            statusCode: 200,
            body: #"{"locked":false,"plan":"equipes","trial":false,"expiresAt":1780499999000}"#
        )
    ])
    let service = FirebaseAuthService(session: session)

    let verified = try await service.verifiedSession(makeAuthSession(lastVerifiedAt: nil))

    #expect(verified.idToken == "fresh-token")
    #expect(verified.refreshToken == "fresh-refresh")
    #expect(verified.plan == .equipes)
    #expect(verified.subscriptionStatus == "active")
    #expect(!verified.isLocked)
}

private func makeFirebaseToken(
    uid: String,
    email: String,
    audience: String = FirebaseAuthService.firebaseProjectID,
    issuer: String = FirebaseAuthService.firebaseIssuer
) -> String {
    let header = base64URL(Data(#"{"alg":"none","typ":"JWT"}"#.utf8))
    let payload = base64URL(Data(#"{"user_id":"\#(uid)","email":"\#(email)","aud":"\#(audience)","iss":"\#(issuer)","iat":1700000000,"exp":1700003600}"#.utf8))
    return "\(header).\(payload).test"
}

private func makeAuthSession(lastVerifiedAt: Date?) -> LuumAuthSession {
    LuumAuthSession(
        uid: "firebase-user",
        email: "user@luum.app",
        displayName: "User",
        idToken: "token",
        refreshToken: "refresh",
        plan: .profissional,
        subscriptionStatus: "active",
        lockedReason: nil,
        expiresAt: Date().addingTimeInterval(3600),
        trialEndsAt: nil,
        lastVerifiedAt: lastVerifiedAt
    )
}

private struct MockResponse: Sendable {
    let url: String
    let statusCode: Int
    let body: String
}

private final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var responses: [MockResponse] = []
    nonisolated(unsafe) static var observedRequests: [URLRequest] = []

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.observedRequests.append(request)
        guard let url = request.url?.absoluteString else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        guard let index = Self.responses.firstIndex(where: { $0.url == url }) else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }

        let response = Self.responses.remove(at: index)
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
    static func mocking(_ responses: [MockResponse]) -> URLSession {
        MockURLProtocol.responses = responses
        MockURLProtocol.observedRequests = []
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}

private func base64URL(_ data: Data) -> String {
    data.base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
}
#endif
