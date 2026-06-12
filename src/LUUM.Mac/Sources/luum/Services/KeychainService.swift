import Foundation
import CryptoKit
import Security

struct KeychainService {
    private let service = "com.zainlet.luum"
    private let fallbackVersionPrefix = "v2:"
    private let legacyFallbackVersionPrefix = "v1:"
    private static let legacySystemKeychainAccounts = ["login"]
    private let useSystemKeychain: Bool
    private let installationSecretURLOverride: URL?

    init(
        useSystemKeychain: Bool = ProcessInfo.processInfo.environment["LUUM_USE_SYSTEM_KEYCHAIN"] == "1",
        installationSecretURL: URL? = nil
    ) {
        self.useSystemKeychain = useSystemKeychain
        self.installationSecretURLOverride = installationSecretURL
    }

    var storageDescription: String {
        useSystemKeychain
            ? "Chaves do macOS"
            : "Cofre local cifrado, sem Chaves do macOS"
    }

    func installationID() -> String? {
        guard let secret = installationSecretForWriting() else { return nil }
        var data = Data("\(service)\u{0}installation-id".utf8)
        data.append(0)
        data.append(secret)
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    func setString(_ value: String, for account: String) throws {
        try setData(Data(value.utf8), for: account)
    }

    func string(for account: String) -> String? {
        data(for: account).flatMap { String(data: $0, encoding: .utf8) }
    }

    func setCodable<T: Codable>(_ value: T, for account: String) throws {
        let data = try JSONEncoder().encode(value)
        try setData(data, for: account)
    }

    func codable<T: Codable>(_ type: T.Type, for account: String) -> T? {
        guard let data = data(for: account) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    func removeValue(for account: String) {
        guard useSystemKeychain else {
            UserDefaults.standard.removeObject(forKey: fallbackKey(for: account))
            Self.deleteSystemKeychainValue(
                service: service,
                account: account,
                suppressAuthenticationUI: true
            )
            return
        }

        Self.deleteSystemKeychainValue(service: service, account: account)
        UserDefaults.standard.removeObject(forKey: fallbackKey(for: account))
    }

    func removeLegacySystemKeychainItems() {
        guard !useSystemKeychain else { return }

        for account in Self.legacySystemKeychainAccounts {
            Self.deleteSystemKeychainValue(
                service: service,
                account: account,
                suppressAuthenticationUI: true
            )
        }
    }

    private func setData(_ data: Data, for account: String) throws {
        guard useSystemKeychain else {
            setFallbackData(data, for: account)
            return
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data,
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }

        if updateStatus != errSecItemNotFound {
            setFallbackData(data, for: account)
            return
        }

        var insertQuery = query
        insertQuery[kSecValueData as String] = data
        insertQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let addStatus = SecItemAdd(insertQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            setFallbackData(data, for: account)
            return
        }

        UserDefaults.standard.removeObject(forKey: fallbackKey(for: account))
    }

    private func data(for account: String) -> Data? {
        guard useSystemKeychain else {
            return fallbackData(for: account)
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else { return fallbackData(for: account) }
        return item as? Data
    }

    @discardableResult
    private static func deleteSystemKeychainValue(
        service: String,
        account: String,
        suppressAuthenticationUI: Bool = false
    ) -> OSStatus {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]

        if suppressAuthenticationUI {
            query[kSecUseAuthenticationUI as String] = kSecUseAuthenticationUISkip
        }

        return SecItemDelete(query as CFDictionary)
    }

    private func fallbackKey(for account: String) -> String {
        "luum.fallback-secret.\(account)"
    }

    private func setFallbackData(_ data: Data, for account: String) {
        let accountData = Data(account.utf8)
        let encryption = fallbackEncryptionForWriting()
        guard
            let sealed = try? AES.GCM.seal(data, using: encryption.key, authenticating: accountData),
            let combined = sealed.combined
        else {
            UserDefaults.standard.removeObject(forKey: fallbackKey(for: account))
            return
        }

        UserDefaults.standard.set(
            encryption.prefix + combined.base64EncodedString(),
            forKey: fallbackKey(for: account)
        )
    }

    private func fallbackData(for account: String) -> Data? {
        guard let raw = UserDefaults.standard.string(forKey: fallbackKey(for: account)) else { return nil }
        if raw.hasPrefix(fallbackVersionPrefix) {
            let encoded = String(raw.dropFirst(fallbackVersionPrefix.count))
            guard
                let combined = Data(base64Encoded: encoded),
                let sealed = try? AES.GCM.SealedBox(combined: combined)
            else {
                return nil
            }

            guard let key = fallbackEncryptionKeyForReading() else { return nil }
            return try? AES.GCM.open(
                sealed,
                using: key,
                authenticating: Data(account.utf8)
            )
        }
        if raw.hasPrefix(legacyFallbackVersionPrefix) {
            let encoded = String(raw.dropFirst(legacyFallbackVersionPrefix.count))
            guard
                let combined = Data(base64Encoded: encoded),
                let sealed = try? AES.GCM.SealedBox(combined: combined),
                let legacyData = try? AES.GCM.open(
                    sealed,
                    using: legacyFallbackEncryptionKey,
                    authenticating: Data(account.utf8)
                )
            else {
                return nil
            }
            setFallbackData(legacyData, for: account)
            return legacyData
        }

        // Migra o fallback Base64 usado por builds anteriores para armazenamento cifrado.
        guard let legacyData = Data(base64Encoded: raw) else { return nil }
        setFallbackData(legacyData, for: account)
        return legacyData
    }

    private struct FallbackEncryption {
        let prefix: String
        let key: SymmetricKey
    }

    private func fallbackEncryptionForWriting() -> FallbackEncryption {
        guard let secret = installationSecretForWriting() else {
            return FallbackEncryption(prefix: legacyFallbackVersionPrefix, key: legacyFallbackEncryptionKey)
        }

        return FallbackEncryption(prefix: fallbackVersionPrefix, key: fallbackEncryptionKey(secret: secret))
    }

    private func fallbackEncryptionKeyForReading() -> SymmetricKey? {
        guard let secret = existingInstallationSecret() else { return nil }
        return fallbackEncryptionKey(secret: secret)
    }

    private func fallbackEncryptionKey(secret: Data) -> SymmetricKey {
        // Builds ad-hoc trocam de assinatura e fazem o Keychain pedir senha.
        // Por padrão usamos fallback cifrado local para evitar esse prompt.
        let material = "\(service)\u{0}\(NSUserName())\u{0}\(NSHomeDirectory())"
        var data = Data(material.utf8)
        data.append(0)
        data.append(secret)
        return SymmetricKey(data: SHA256.hash(data: data))
    }

    private var legacyFallbackEncryptionKey: SymmetricKey {
        let material = "\(service)\u{0}\(NSUserName())\u{0}\(NSHomeDirectory())"
        return SymmetricKey(data: SHA256.hash(data: Data(material.utf8)))
    }

    private func existingInstallationSecret() -> Data? {
        let url = installationSecretURL()
        if let data = try? Data(contentsOf: url), data.count >= 32 {
            return data
        }

        return nil
    }

    private func installationSecretForWriting() -> Data? {
        if let existing = existingInstallationSecret() {
            return existing
        }

        let url = installationSecretURL()

        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        let secret = status == errSecSuccess
            ? Data(bytes)
            : Data(SHA256.hash(data: Data("\(service)\u{0}\(UUID().uuidString)".utf8)))

        do {
            let directory = url.deletingLastPathComponent()
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            try secret.write(to: url, options: [.atomic])
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        } catch {
            return nil
        }

        return secret
    }

    private func installationSecretURL() -> URL {
        if let installationSecretURLOverride {
            return installationSecretURLOverride
        }

        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ??
            URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support", isDirectory: true)
        return base
            .appendingPathComponent("Luum", isDirectory: true)
            .appendingPathComponent(".local-vault-key", isDirectory: false)
    }
}

#if DEBUG
extension KeychainService {
    static var legacySystemKeychainAccountsForTesting: [String] {
        legacySystemKeychainAccounts
    }

    func setFallbackStringForTesting(_ value: String, for account: String) {
        setFallbackData(Data(value.utf8), for: account)
    }

    func setLegacyFallbackStringForTesting(_ value: String, for account: String) {
        UserDefaults.standard.set(
            Data(value.utf8).base64EncodedString(),
            forKey: fallbackKey(for: account)
        )
    }

    func setLegacyEncryptedFallbackStringForTesting(_ value: String, for account: String) {
        let accountData = Data(account.utf8)
        guard
            let sealed = try? AES.GCM.seal(
                Data(value.utf8),
                using: legacyFallbackEncryptionKey,
                authenticating: accountData
            ),
            let combined = sealed.combined
        else { return }

        UserDefaults.standard.set(
            legacyFallbackVersionPrefix + combined.base64EncodedString(),
            forKey: fallbackKey(for: account)
        )
    }

    func rawFallbackStringForTesting(account: String) -> String? {
        UserDefaults.standard.string(forKey: fallbackKey(for: account))
    }
}
#endif

struct KeychainServiceError: LocalizedError {
    let status: OSStatus

    var errorDescription: String? {
        SecCopyErrorMessageString(status, nil) as String? ?? "Erro de Keychain (\(status))."
    }
}
