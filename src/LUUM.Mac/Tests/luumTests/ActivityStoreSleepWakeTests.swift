import Foundation

#if canImport(Testing)
import Testing
@testable import luum

@MainActor
@Test
func systemSleepPausesMonitoringAndMarksSleepResumeFlag() {
    let store = ActivityStore()
    store.authSession = activeSessionForSleepWakeTesting()
    store.setSleepWakeStateForTesting(isMonitoring: true, monitoringPausedForSleep: false)

    store.handleSystemWillSleep()

    #expect(store.monitoringPausedForSleepForTesting)
    #expect(store.isMonitoring == false)
}

@MainActor
@Test
func systemWakeResumesOnlyWhenMonitoringWasPausedForSleep() {
    let store = ActivityStore()
    store.authSession = activeSessionForSleepWakeTesting()
    store.setSleepWakeStateForTesting(isMonitoring: false, monitoringPausedForSleep: true)

    store.handleSystemDidWake()

    #expect(store.monitoringPausedForSleepForTesting == false)
    #expect(store.isMonitoring)

    store.stopMonitoring()
}

@MainActor
@Test
func systemWakeDoesNotResumeWhenUserHadAlreadyPausedMonitoring() {
    let store = ActivityStore()
    store.authSession = activeSessionForSleepWakeTesting()
    store.setSleepWakeStateForTesting(isMonitoring: false, monitoringPausedForSleep: false)

    store.handleSystemWillSleep()
    #expect(store.monitoringPausedForSleepForTesting == false)

    store.handleSystemDidWake()

    #expect(store.monitoringPausedForSleepForTesting == false)
    #expect(store.isMonitoring == false)
}

private func activeSessionForSleepWakeTesting() -> LuumAuthSession {
    LuumAuthSession(
        uid: "sleep-wake-test",
        email: "sleepwake@example.com",
        displayName: "Sleep Wake Test",
        idToken: "test-token",
        refreshToken: nil,
        plan: .equipes,
        subscriptionStatus: "active",
        lockedReason: nil,
        expiresAt: Date().addingTimeInterval(3_600),
        trialEndsAt: nil,
        lastVerifiedAt: Date()
    )
}
#endif
