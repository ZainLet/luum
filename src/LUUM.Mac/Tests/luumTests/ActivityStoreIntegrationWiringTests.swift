import Foundation

#if canImport(Testing)
import Testing
@testable import luum

@MainActor
@Test
func notionOAuthCallbackEnablesIntegrationAndStoresWorkspaceMetadata() throws {
    let context = try makeIntegrationWiringTestContext()
    defer { context.cleanup() }

    let store = makeIntegrationWiringStore(context: context)
    let url = try #require(
        URL(string: "luum://auth/notion/callback?access_token=notion-token&workspace_name=Ops%20Notion")
    )

    store.handleNotionOAuthCallback(url)

    #expect(context.keychain.string(for: ActivityStore.notionCalendarTokenKey) == "notion-token")
    #expect(store.monitoringPreferences.notionCalendarSettings.isEnabled)
    #expect(store.monitoringPreferences.notionCalendarSettings.workspaceLabel == "Ops Notion")
    #expect(store.notionCalendarStatusMessage == "Notion conectado: Ops Notion. Configure as fontes de data abaixo.")
}

@MainActor
@Test
func clickUpOAuthCallbackStoresTokenAndMapsOAuthErrors() throws {
    let context = try makeIntegrationWiringTestContext()
    defer { context.cleanup() }

    let store = makeIntegrationWiringStore(context: context)
    let successURL = try #require(URL(string: "luum://auth/clickup/callback?access_token=clickup-token"))

    store.handleClickUpOAuthCallback(successURL)

    #expect(context.keychain.string(for: ActivityStore.clickUpTokenKey) == "clickup-token")
    #expect(store.clickUpStatusMessage == "ClickUp conectado com sucesso.")

    let errorURL = try #require(URL(string: "luum://auth/clickup/callback?error=access_denied"))
    store.handleClickUpOAuthCallback(errorURL)

    #expect(store.clickUpStatusMessage == "Autorização negada. Permita o acesso para conectar.")
}

@MainActor
@Test
func linearOAuthCallbackStoresBearerTokenAndHandlesKnownErrors() throws {
    let context = try makeIntegrationWiringTestContext()
    defer { context.cleanup() }

    let store = makeIntegrationWiringStore(context: context)
    let successURL = try #require(
        URL(string: "luum://auth/linear/callback?access_token=linear-token&token_type=Bearer")
    )

    store.handleLinearOAuthCallback(successURL)

    #expect(context.keychain.string(for: ActivityStore.linearTokenKey) == "Bearer linear-token")
    #expect(store.linearStatusMessage == "Linear conectado com sucesso.")

    let errorURL = try #require(URL(string: "luum://auth/linear/callback?error=server_not_configured"))
    store.handleLinearOAuthCallback(errorURL)

    #expect(store.linearStatusMessage == "Linear não está configurado no servidor.")
}

private func makeIntegrationWiringStore(context: IntegrationWiringTestContext) -> ActivityStore {
    ActivityStore(
        persistence: ActivityPersistence(directoryURL: context.temporaryDirectory.appendingPathComponent("activity")),
        googleCalendarPersistence: GoogleCalendarPersistence(fileManager: context.fileManager),
        monitoringPreferencesPersistence: MonitoringPreferencesPersistence(fileManager: context.fileManager),
        keychainService: context.keychain
    )
}

private func makeIntegrationWiringTestContext() throws -> IntegrationWiringTestContext {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("luum-integration-wiring-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    let fileManager = TemporaryApplicationSupportFileManager(directoryURL: temporaryDirectory)
    let keychain = KeychainService(
        installationSecretURL: temporaryDirectory.appendingPathComponent(".local-vault-key")
    )
    return IntegrationWiringTestContext(
        temporaryDirectory: temporaryDirectory,
        fileManager: fileManager,
        keychain: keychain
    )
}

private struct IntegrationWiringTestContext {
    let temporaryDirectory: URL
    let fileManager: TemporaryApplicationSupportFileManager
    let keychain: KeychainService

    func cleanup() {
        keychain.removeValue(for: ActivityStore.notionCalendarTokenKey)
        keychain.removeValue(for: ActivityStore.clickUpTokenKey)
        keychain.removeValue(for: ActivityStore.linearTokenKey)
        try? FileManager.default.removeItem(at: temporaryDirectory)
    }
}
#endif
