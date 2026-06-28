import Foundation

#if canImport(Testing)
import Testing
@testable import luum

@MainActor
@Test
func signOutClearsWorkspaceConfigurationAndParticipation() throws {
    let context = try makeSignOutTestContext()
    defer { context.cleanup() }

    try context.keychain.setCodable(
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
        persistence: ActivityPersistence(directoryURL: context.temporaryDirectory.appendingPathComponent("activity")),
        googleCalendarPersistence: GoogleCalendarPersistence(fileManager: context.fileManager),
        monitoringPreferencesPersistence: MonitoringPreferencesPersistence(fileManager: context.fileManager),
        keychainService: context.keychain
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

@MainActor
@Test
func signOutClearsOAuthAndAISecrets() throws {
    let context = try makeSignOutTestContext()
    defer { context.cleanup() }

    let keychain = context.keychain
    let googleConnection = GoogleCalendarConnectionSnapshot(
        id: "google-1",
        profile: GoogleCalendarProfile(email: "calendar@example.com", name: "Calendar Test", pictureURL: nil),
        calendars: [GoogleCalendarDescriptor(id: "primary", title: "Principal", isPrimary: true)],
        agendaDay: nil,
        agendaItems: [],
        lastSyncAt: nil
    )

    try keychain.setCodable(
        LuumAuthSession(
            uid: "token-sign-out-test",
            email: "tokens@example.com",
            displayName: "Token Test",
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
    try keychain.setString("workspace-secret", for: ActivityStore.teamWorkspaceSecretKey)
    try keychain.setString("notion-token", for: ActivityStore.notionCalendarTokenKey)
    try keychain.setString("clickup-token", for: ActivityStore.clickUpTokenKey)
    try keychain.setString("linear-token", for: ActivityStore.linearTokenKey)
    try keychain.setString("ai-key", for: ActivityStore.aiClassificationAPIKeyKey)
    try keychain.setCodable(
        OutlookCalendarTokens.make(accessToken: "outlook-access", refreshToken: "outlook-refresh", expiresIn: 3600),
        for: ActivityStore.outlookCalendarSessionKey
    )
    try keychain.setCodable(
        OutlookCalendarTokens.make(accessToken: "outlook-token", refreshToken: "outlook-refresh", expiresIn: 3600),
        for: ActivityStore.outlookCalendarTokenKey
    )
    try keychain.setCodable(
        GoogleCalendarTokens(refreshToken: "google-refresh", idToken: "google-id"),
        for: ActivityStore.googleCalendarTokenKey(googleConnection.id)
    )

    let store = ActivityStore(
        persistence: ActivityPersistence(directoryURL: context.temporaryDirectory.appendingPathComponent("activity")),
        googleCalendarPersistence: GoogleCalendarPersistence(fileManager: context.fileManager),
        monitoringPreferencesPersistence: MonitoringPreferencesPersistence(fileManager: context.fileManager),
        keychainService: keychain
    )
    store.googleCalendarConnections = [googleConnection]

    #expect(keychain.string(for: ActivityStore.teamWorkspaceSecretKey) == "workspace-secret")
    #expect(keychain.string(for: ActivityStore.notionCalendarTokenKey) == "notion-token")
    #expect(keychain.string(for: ActivityStore.clickUpTokenKey) == "clickup-token")
    #expect(keychain.string(for: ActivityStore.linearTokenKey) == "linear-token")
    #expect(keychain.string(for: ActivityStore.aiClassificationAPIKeyKey) == "ai-key")
    #expect(keychain.codable(OutlookCalendarTokens.self, for: ActivityStore.outlookCalendarSessionKey) != nil)
    #expect(keychain.codable(OutlookCalendarTokens.self, for: ActivityStore.outlookCalendarTokenKey) != nil)
    #expect(keychain.codable(GoogleCalendarTokens.self, for: ActivityStore.googleCalendarTokenKey(googleConnection.id)) != nil)

    store.signOut()

    #expect(keychain.codable(LuumAuthSession.self, for: "firebase-auth-session") == nil)
    #expect(keychain.string(for: ActivityStore.teamWorkspaceSecretKey) == nil)
    #expect(keychain.string(for: ActivityStore.notionCalendarTokenKey) == nil)
    #expect(keychain.string(for: ActivityStore.clickUpTokenKey) == nil)
    #expect(keychain.string(for: ActivityStore.linearTokenKey) == nil)
    #expect(keychain.string(for: ActivityStore.aiClassificationAPIKeyKey) == nil)
    #expect(keychain.codable(OutlookCalendarTokens.self, for: ActivityStore.outlookCalendarSessionKey) == nil)
    #expect(keychain.codable(OutlookCalendarTokens.self, for: ActivityStore.outlookCalendarTokenKey) == nil)
    #expect(keychain.codable(GoogleCalendarTokens.self, for: ActivityStore.googleCalendarTokenKey(googleConnection.id)) == nil)
    #expect(store.googleCalendarConnections.isEmpty)
}

private func makeSignOutTestContext() throws -> SignOutTestContext {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("luum-sign-out-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    let fileManager = TemporaryApplicationSupportFileManager(directoryURL: temporaryDirectory)
    let keychain = KeychainService(
        installationSecretURL: temporaryDirectory.appendingPathComponent(".local-vault-key")
    )
    return SignOutTestContext(
        temporaryDirectory: temporaryDirectory,
        fileManager: fileManager,
        keychain: keychain
    )
}

private struct SignOutTestContext {
    let temporaryDirectory: URL
    let fileManager: TemporaryApplicationSupportFileManager
    let keychain: KeychainService

    func cleanup() {
        keychain.removeValue(for: "firebase-auth-session")
        keychain.removeValue(for: ActivityStore.teamWorkspaceSecretKey)
        keychain.removeValue(for: ActivityStore.notionCalendarTokenKey)
        keychain.removeValue(for: ActivityStore.clickUpTokenKey)
        keychain.removeValue(for: ActivityStore.linearTokenKey)
        keychain.removeValue(for: ActivityStore.aiClassificationAPIKeyKey)
        keychain.removeValue(for: ActivityStore.outlookCalendarSessionKey)
        keychain.removeValue(for: ActivityStore.outlookCalendarTokenKey)
        try? FileManager.default.removeItem(at: temporaryDirectory)
    }
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
