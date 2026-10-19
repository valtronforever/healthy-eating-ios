import Foundation
import Security

/// Small byte storage keyed by account. Tokens live here and nowhere else (AGENTS.md).
nonisolated protocol SecureStore: Sendable {
    func read(_ account: String) -> Data?
    func write(_ data: Data, for account: String) -> Bool
    func delete(_ account: String)
}

/// The system Keychain: generic passwords, this device only, readable after the first unlock
/// (so background refreshes and widgets can read them).
nonisolated struct Keychain: SecureStore {
    var service = "io.github.valtronforever.HealthyEating"

    private func query(_ account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    func read(_ account: String) -> Data? {
        var query = query(account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }

    func write(_ data: Data, for account: String) -> Bool {
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let status = SecItemUpdate(query(account) as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            let item = query(account).merging(attributes) { _, new in new }
            return SecItemAdd(item as CFDictionary, nil) == errSecSuccess
        }
        return status == errSecSuccess
    }

    func delete(_ account: String) {
        SecItemDelete(query(account) as CFDictionary)
    }
}

/// An in-memory store for previews, UI tests and unit tests.
nonisolated final class MemoryStore: SecureStore, @unchecked Sendable {
    private let lock = NSLock()
    private var items: [String: Data] = [:]

    func read(_ account: String) -> Data? {
        lock.withLock { items[account] }
    }

    func write(_ data: Data, for account: String) -> Bool {
        lock.withLock { items[account] = data }
        return true
    }

    func delete(_ account: String) {
        _ = lock.withLock { items.removeValue(forKey: account) }
    }
}

/// Credentials per server, stored as JSON in a `SecureStore`.
nonisolated struct CredentialStore: Sendable {
    let store: any SecureStore

    private func account(for server: ServerAddress) -> String {
        "credentials:\(server.baseURL.absoluteString)"
    }

    func hasCredentials(for server: ServerAddress) -> Bool {
        credentials(for: server) != nil
    }

    func credentials(for server: ServerAddress) -> Credentials? {
        store.read(account(for: server)).flatMap { try? JSONDecoder().decode(Credentials.self, from: $0) }
    }

    @discardableResult
    func save(_ credentials: Credentials, for server: ServerAddress) -> Bool {
        guard let data = try? JSONEncoder().encode(credentials) else { return false }
        return store.write(data, for: account(for: server))
    }

    /// Deletes the tokens. The registered client stays, so signing in again reuses it.
    func delete(for server: ServerAddress) {
        store.delete(account(for: server))
    }

    func clientID(for server: ServerAddress) -> String? {
        store.read("client:\(server.baseURL.absoluteString)").flatMap { String(data: $0, encoding: .utf8) }
    }

    func saveClientID(_ clientID: String, for server: ServerAddress) {
        _ = store.write(Data(clientID.utf8), for: "client:\(server.baseURL.absoluteString)")
    }
}
