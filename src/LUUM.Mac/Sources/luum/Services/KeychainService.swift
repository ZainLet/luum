import Foundation
import Security

struct KeychainService {
    private let service = "com.zainlet.luum"

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
        UserDefaults.standard.set(data.base64EncodedString(), forKey: fallbackKey(for: account))
    }

    private func fallbackData(for account: String) -> Data? {
        guard let raw = UserDefaults.standard.string(forKey: fallbackKey(for: account)) else { return nil }
        return Data(base64Encoded: raw)
    }
}

struct KeychainServiceError: LocalizedError {
    let status: OSStatus

    var errorDescription: String? {
        SecCopyErrorMessageString(status, nil) as String? ?? "Erro de Keychain (\(status))."
    }
}
