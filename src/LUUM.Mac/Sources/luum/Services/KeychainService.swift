import Foundation
import CryptoKit
import Security

struct KeychainService {
    private let service = "com.zainlet.luum"
    private let fallbackVersionPrefix = "v1:"

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
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
        UserDefaults.standard.removeObject(forKey: fallbackKey(for: account))
    }

    private func setData(_ data: Data, for account: String) throws {
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

    private func fallbackKey(for account: String) -> String {
        "luum.fallback-secret.\(account)"
    }

    private func setFallbackData(_ data: Data, for account: String) {
        let accountData = Data(account.utf8)
        guard
            let sealed = try? AES.GCM.seal(data, using: fallbackEncryptionKey, authenticating: accountData),
            let combined = sealed.combined
        else {
            UserDefaults.standard.removeObject(forKey: fallbackKey(for: account))
            return
        }

        UserDefaults.standard.set(
            fallbackVersionPrefix + combined.base64EncodedString(),
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

            return try? AES.GCM.open(
                sealed,
                using: fallbackEncryptionKey,
                authenticating: Data(account.utf8)
            )
        }

        // Migra o fallback Base64 usado por builds anteriores para armazenamento cifrado.
        guard let legacyData = Data(base64Encoded: raw) else { return nil }
        setFallbackData(legacyData, for: account)
        return legacyData
    }

    private var fallbackEncryptionKey: SymmetricKey {
        // Builds ad-hoc podem perder acesso ao Keychain. A chave derivada da conta local
        // reduz exposição casual em disco, mas não substitui o Keychain em distribuição.
        let material = "\(service)\u{0}\(NSUserName())\u{0}\(NSHomeDirectory())"
        return SymmetricKey(data: SHA256.hash(data: Data(material.utf8)))
    }
}

struct KeychainServiceError: LocalizedError {
    let status: OSStatus

    var errorDescription: String? {
        SecCopyErrorMessageString(status, nil) as String? ?? "Erro de Keychain (\(status))."
    }
}
