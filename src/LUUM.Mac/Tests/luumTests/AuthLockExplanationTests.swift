#if canImport(Testing)
import Foundation
import Testing
@testable import luum

@Test
func deviceLimitLockUsesFriendlyExplanation() {
    let session = LuumAuthSession(
        uid: "firebase-user",
        email: "user@luum.app",
        displayName: "User",
        idToken: "token",
        refreshToken: "refresh",
        plan: .profissional,
        subscriptionStatus: "active",
        lockedReason: "device_limit_exceeded",
        expiresAt: Date().addingTimeInterval(3600),
        trialEndsAt: nil,
        lastVerifiedAt: Date().addingTimeInterval(-60)
    )

    #expect(session.isLocked)
    #expect(session.lockExplanation?.contains("limite de Macs autorizados") == true)
    #expect(session.lockExplanation?.contains("device_limit_exceeded") == false)
}
#endif
