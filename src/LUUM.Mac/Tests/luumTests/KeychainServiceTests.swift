import Foundation

#if canImport(Testing)
import Testing
@testable import luum

@Test
func defaultStorageUsesEncryptedFallbackWithoutSystemKeychain() throws {
    let keychain = KeychainService()
    let account = "test-default-fallback-\(UUID().uuidString)"
    defer { keychain.removeValue(for: account) }

    #expect(keychain.storageDescription.contains("sem Chaves do macOS"))

    try keychain.setString("no-keychain-prompt", for: account)

    let raw = try #require(keychain.rawFallbackStringForTesting(account: account))
    #expect(raw.hasPrefix("v2:"))
    #expect(!raw.contains("no-keychain-prompt"))
    #expect(keychain.string(for: account) == "no-keychain-prompt")

    keychain.removeValue(for: account)
    #expect(keychain.rawFallbackStringForTesting(account: account) == nil)
}

@Test
func defaultStorageCanCleanLegacyLoginKeyWithoutEnablingSystemKeychain() {
    let keychain = KeychainService()

    #expect(keychain.storageDescription.contains("sem Chaves do macOS"))
    #expect(KeychainService.systemKeychainServiceForTesting == "com.luum.apple")
    #expect(KeychainService.legacySystemKeychainServicesForTesting.contains("com.zainlet.luum"))
    #expect(KeychainService.legacySystemKeychainAccountsForTesting.contains("login"))

    keychain.removeLegacySystemKeychainItems()
}

@Test
func explicitSystemKeychainModeIsVisibleForDiagnostics() {
    let keychain = KeychainService(useSystemKeychain: true)

    #expect(keychain.storageDescription == "Chaves do macOS")
}

@Test
func installationIDIsStableAndDerivedFromLocalSecret() throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("luum-installation-id-test-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let secretURL = temporaryDirectory.appendingPathComponent(".local-vault-key", isDirectory: false)
    let first = KeychainService(installationSecretURL: secretURL)
    let second = KeychainService(installationSecretURL: secretURL)

    let firstID = try #require(first.installationID())
    let secondID = try #require(second.installationID())

    #expect(firstID == secondID)
    #expect(firstID.count == 64)
    #expect(!firstID.contains("local-vault-key"))
}

@Test
func encryptedFallbackRoundTripsAndBindsToAccount() throws {
    let keychain = KeychainService()
    let account = "test-fallback-\(UUID().uuidString)"
    let otherAccount = "\(account)-other"
    defer {
        keychain.removeValue(for: account)
        keychain.removeValue(for: otherAccount)
    }

    keychain.setFallbackStringForTesting("firebase-session-token", for: account)

    let raw = try #require(keychain.rawFallbackStringForTesting(account: account))
    #expect(raw.hasPrefix("v2:"))
    #expect(!raw.contains("firebase-session-token"))
    #expect(keychain.string(for: account) == "firebase-session-token")
    #expect(keychain.string(for: otherAccount) == nil)
}

@Test
func legacyFallbackMigratesToEncryptedFormat() throws {
    let keychain = KeychainService()
    let account = "test-legacy-fallback-\(UUID().uuidString)"
    defer { keychain.removeValue(for: account) }

    keychain.setLegacyFallbackStringForTesting("legacy-secret", for: account)

    #expect(keychain.string(for: account) == "legacy-secret")
    let migrated = try #require(keychain.rawFallbackStringForTesting(account: account))
    #expect(migrated.hasPrefix("v2:"))
    #expect(!migrated.contains("legacy-secret"))
}

@Test
func legacyEncryptedFallbackMigratesToInstallSecretBackedFormat() throws {
    let keychain = KeychainService()
    let account = "test-legacy-v1-fallback-\(UUID().uuidString)"
    defer { keychain.removeValue(for: account) }

    keychain.setLegacyEncryptedFallbackStringForTesting("legacy-encrypted-secret", for: account)
    let legacy = try #require(keychain.rawFallbackStringForTesting(account: account))
    #expect(legacy.hasPrefix("v1:"))

    #expect(keychain.string(for: account) == "legacy-encrypted-secret")
    let migrated = try #require(keychain.rawFallbackStringForTesting(account: account))
    #expect(migrated.hasPrefix("v2:"))
    #expect(!migrated.contains("legacy-encrypted-secret"))
}

@Test
func fallbackUsesStableLegacyEncryptionWhenInstallationSecretCannotPersist() throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("luum-keychain-test-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let blockedDirectory = temporaryDirectory.appendingPathComponent("blocked", isDirectory: true)
    try Data("not-a-directory".utf8).write(to: blockedDirectory)

    let secretURL = blockedDirectory.appendingPathComponent(".local-vault-key", isDirectory: false)
    let account = "test-unwritable-secret-\(UUID().uuidString)"
    let keychain = KeychainService(installationSecretURL: secretURL)
    defer { keychain.removeValue(for: account) }

    try keychain.setString("stable-local-secret", for: account)

    let raw = try #require(keychain.rawFallbackStringForTesting(account: account))
    #expect(raw.hasPrefix("v1:"))
    #expect(!raw.contains("stable-local-secret"))
    #expect(keychain.string(for: account) == "stable-local-secret")
    #expect(KeychainService(installationSecretURL: secretURL).string(for: account) == "stable-local-secret")
}
#endif
