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
func localSessionLocksWithoutRecentServerVerification() {
    let verifiedRecently = makeAuthSession(lastVerifiedAt: Date().addingTimeInterval(-60))
    let staleVerification = makeAuthSession(lastVerifiedAt: Date().addingTimeInterval(-(LuumAuthSession.offlineGracePeriod + 60)))
    let neverVerified = makeAuthSession(lastVerifiedAt: nil)

    #expect(!verifiedRecently.isLocked)
    #expect(staleVerification.isLocked)
    #expect(neverVerified.isLocked)
}

private func makeFirebaseToken(uid: String, email: String) -> String {
    let header = base64URL(Data(#"{"alg":"none","typ":"JWT"}"#.utf8))
    let payload = base64URL(Data(#"{"user_id":"\#(uid)","email":"\#(email)","iat":1700000000,"exp":1700003600}"#.utf8))
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

private func base64URL(_ data: Data) -> String {
    data.base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
}
#endif
