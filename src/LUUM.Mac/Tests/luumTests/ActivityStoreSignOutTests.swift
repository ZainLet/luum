import Foundation

#if canImport(Testing)
import Testing
@testable import luum

@MainActor
@Test
func signOutClearsWorkspaceConfigurationAndParticipation() throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("luum-sign-out-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let fileManager = TemporaryApplicationSupportFileManager(directoryURL: temporaryDirectory)
    let keychain = KeychainService(
        installationSecretURL: temporaryDirectory.appendingPathComponent(".local-vault-key")
    )
    defer {
        keychain.removeValue(for: "firebase-auth-session")
        keychain.removeValue(for: "team-workspace-secret")
    }

    try keychain.setCodable(
        LuumAuthSession(
            uid: "workspace-sign-out-test",
            email: "workspace@example.com",
            displayName: "Workspace Test",
            idToken: "test-token",
            refreshToken: nil,
            plan: .equipes,
            subscriptionStatus: "active",
            lockedReason: nil,
            expiresAt: Date().addingTimeInterval(3_600),
            trialEndsAt: nil,
            lastVerifiedAt: Date()
        ),
        for: "firebase-auth-session"
    )

    let store = ActivityStore(
        persistence: ActivityPersistence(directoryURL: temporaryDirectory.appendingPathComponent("activity")),
        googleCalendarPersistence: GoogleCalendarPersistence(fileManager: fileManager),
        monitoringPreferencesPersistence: MonitoringPreferencesPersistence(fileManager: fileManager),
        keychainService: keychain
    )
    store.updateTeamWorkspaceID("workspace-test")
    store.updateTeamSharesAnonymousMetrics(true)
    store.updateTeamAutomaticallySyncWorkspace(true)
    store.updateTeamWorkspaceSecret("workspace-secret")

    #expect(store.teamWorkspaceConfigured)
    #expect(store.teamSettings.sharesAnonymousMetrics)
    #expect(store.teamSettings.automaticallySyncWorkspace)

    store.signOut()

    #expect(!store.teamWorkspaceConfigured)
    #expect(!store.hasWorkspaceSecret)
    #expect(!store.teamSettings.sharesAnonymousMetrics)
    #expect(!store.teamSettings.automaticallySyncWorkspace)
    #expect(store.teamSettings.workspaceID.isEmpty)
    #expect(store.workspaceRankingEntries.isEmpty)
    #expect(store.workspaceSyncLastSyncAt == nil)
}

private final class TemporaryApplicationSupportFileManager: FileManager, @unchecked Sendable {
    private let directoryURL: URL

    init(directoryURL: URL) {
        self.directoryURL = directoryURL
        super.init()
    }

    override func urls(
        for directory: FileManager.SearchPathDirectory,
        in domainMask: FileManager.SearchPathDomainMask
    ) -> [URL] {
        if directory == .applicationSupportDirectory, domainMask.contains(.userDomainMask) {
            return [directoryURL]
        }
        return super.urls(for: directory, in: domainMask)
    }
}
#endif
