import Foundation

#if canImport(Testing)
import Testing
@testable import luum

@Test
func defaultStorageUsesEncryptedFallbackWithoutSystemKeychain() throws {
    let keychain = KeychainService()
    let account = "test-default-fallback-\(UUID().uuidString)"
    defer { keychain.removeValue(for: account) }

    try keychain.setString("no-keychain-prompt", for: account)

    let raw = try #require(keychain.rawFallbackStringForTesting(account: account))
    #expect(raw.hasPrefix("v1:"))
    #expect(!raw.contains("no-keychain-prompt"))
    #expect(keychain.string(for: account) == "no-keychain-prompt")

    keychain.removeValue(for: account)
    #expect(keychain.rawFallbackStringForTesting(account: account) == nil)
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
    #expect(raw.hasPrefix("v1:"))
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
    #expect(migrated.hasPrefix("v1:"))
    #expect(!migrated.contains("legacy-secret"))
}
#endif
