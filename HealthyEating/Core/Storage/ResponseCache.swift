import CryptoKit
import Foundation

/// The last answer of each GET request, kept on the device so the app still shows data when the
/// server can't be reached (ios#20, G1 "offline with cached data"). One folder per server in
/// Application Support, readable after the first unlock (background refresh works) and excluded
/// from backups. Deleted on sign-out and account deletion. Read-only offline: changes always
/// need the server.
nonisolated struct ResponseCache: Sendable {
    let directory: URL

    /// The cache folder of one server.
    static func directory(for server: ServerAddress) -> URL? {
        guard let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let digest = SHA256.hash(data: Data(server.baseURL.absoluteString.utf8)).map { String(format: "%02x", $0) }.joined()
        return support.appending(path: "ResponseCache", directoryHint: .isDirectory).appending(path: String(digest.prefix(32)))
    }

    /// When an answer was saved, and the answer.
    struct Entry: Codable, Equatable {
        var savedAt: Date
        var body: Data
    }

    func store(_ body: Data, for key: String, at date: Date = .now) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            var folder = directory
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try? folder.setResourceValues(values)
            let data = try JSONEncoder().encode(Entry(savedAt: date, body: body))
            try data.write(to: file(for: key), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } catch {
            // A cache that cannot be written only means no offline copy of this answer.
        }
    }

    func entry(for key: String) -> Entry? {
        guard let data = try? Data(contentsOf: file(for: key)) else { return nil }
        return try? JSONDecoder().decode(Entry.self, from: data)
    }

    func removeAll() {
        try? FileManager.default.removeItem(at: directory)
    }

    /// The request path and its query, without the server (the folder is per server).
    static func key(path: String, query: [URLQueryItem]) -> String {
        let items = query.map { "\($0.name)=\($0.value ?? "")" }.sorted().joined(separator: "&")
        return items.isEmpty ? path : path + "?" + items
    }

    private func file(for key: String) -> URL {
        let name = SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
        return directory.appending(path: name + ".json")
    }
}
