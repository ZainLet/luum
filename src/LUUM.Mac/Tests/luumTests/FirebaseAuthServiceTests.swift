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
func officialBackendRejectsLocalAndExternalOverrides() {
    #expect(FirebaseAuthService.officialBackendURL(from: FirebaseAuthService.defaultBaseURL)?.absoluteString == FirebaseAuthService.defaultBaseURL)
    #expect(FirebaseAuthService.officialBackendURL(from: "http://localhost:5000") == nil)
    #expect(FirebaseAuthService.officialBackendURL(from: "https://example.com") == nil)
}

private func makeFirebaseToken(uid: String, email: String) -> String {
    let header = base64URL(Data(#"{"alg":"none","typ":"JWT"}"#.utf8))
    let payload = base64URL(Data(#"{"user_id":"\#(uid)","email":"\#(email)","iat":1700000000,"exp":1700003600}"#.utf8))
    return "\(header).\(payload).test"
}

private func base64URL(_ data: Data) -> String {
    data.base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
}
#endif
