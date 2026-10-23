import Foundation
import Testing
@testable import HealthyEating

private func temporaryCache() -> ResponseCache {
    ResponseCache(directory: FileManager.default.temporaryDirectory.appending(path: "ResponseCacheTests-\(UUID())"))
}

struct ResponseCacheTests {
    @Test func keepsTheLastAnswerPerRequest() {
        let cache = temporaryCache()
        let saved = Date(timeIntervalSince1970: 1_792_000_000)
        cache.store(Data("old".utf8), for: "days?from=a", at: saved)
        cache.store(Data("new".utf8), for: "days?from=a", at: saved.addingTimeInterval(60))
        #expect(cache.entry(for: "days?from=a") == .init(savedAt: saved.addingTimeInterval(60), body: Data("new".utf8)))
        #expect(cache.entry(for: "days?from=b") == nil)
        cache.removeAll()
        #expect(cache.entry(for: "days?from=a") == nil)
    }

    @Test func keysIgnoreTheOrderOfQueryItems() {
        let one = ResponseCache.key(path: "days", query: [.init(name: "from", value: "1"), .init(name: "to", value: "2")])
        let two = ResponseCache.key(path: "days", query: [.init(name: "to", value: "2"), .init(name: "from", value: "1")])
        #expect(one == two)
        #expect(ResponseCache.key(path: "me", query: []) == "me")
    }

    @Test func eachServerHasItsOwnFolder() throws {
        let one = try #require(ResponseCache.directory(for: try ServerAddress.parse("https://food.example.com")))
        let two = try #require(ResponseCache.directory(for: try ServerAddress.parse("https://other.example.com")))
        #expect(one != two)
    }
}

struct OfflineBannerTests {
    private let locale = Locale(identifier: "en_US")
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin") ?? .current
        return calendar
    }

    /// The text with ordinary spaces (the formatter puts a narrow no-break space before "AM").
    private func text(_ saved: Date, _ now: Date) -> String {
        OfflineBanner.text(savedAt: saved, now: now, calendar: calendar, locale: locale).replacingOccurrences(of: "\u{202F}", with: " ")
    }

    @Test func todayShowsTheTime() throws {
        let now = try #require(APIDate.parse("2026-10-23T12:00:00+02:00"))
        let saved = try #require(APIDate.parse("2026-10-23T09:42:00+02:00"))
        #expect(text(saved, now) == "Showing data from 9:42 AM. It updates when you are back online.")
    }

    @Test func anEarlierDayShowsTheDateToo() throws {
        let now = try #require(APIDate.parse("2026-10-23T12:00:00+02:00"))
        let saved = try #require(APIDate.parse("2026-10-21T09:42:00+02:00"))
        // "Oct 21 at 9:42 AM" or "Oct 21, 9:42 AM", depending on the OS version.
        let line = text(saved, now)
        #expect(line.hasPrefix("Showing data from Oct 21"))
        #expect(line.hasSuffix("9:42 AM. It updates when you are back online."))
    }
}

@MainActor
struct OfflineStateTests {
    @Test func showsTheOldestKeptAnswerUntilTheServerAnswers() {
        let model = AppModel(defaults: UserDefaults(suiteName: "OfflineStateTests.\(UUID())")!,
                             arguments: [AppModel.LaunchArgument.skipOnboarding])
        let older = Date(timeIntervalSince1970: 1_792_000_000)
        model.cacheUsed(older.addingTimeInterval(600))
        model.cacheUsed(older)
        model.cacheUsed(older.addingTimeInterval(300))
        #expect(model.offlineSince == older)
        model.cacheUsed(nil)
        #expect(model.offlineSince == nil)
    }
}

extension NetworkTests {
    struct OfflineAPITests {
        /// Answers 200 with `body` until `offline` is set, then fails like a lost connection.
        final class Server: @unchecked Sendable {
            var offline = false
            var body = Data(#"{"timezone":"Europe/Berlin","energy_unit":"kcal","calm_mode":false,"targets":{"calories_kcal":null,"protein_g":null,"fat_g":null,"carbohydrates_g":null}}"#.utf8)
        }

        final class Uses: @unchecked Sendable {
            var values: [Date?] = []
        }

        private func client(_ server: Server, cache: ResponseCache, uses: Uses) throws -> APIClient {
            let address = try ServerAddress.parse("https://food.example.com")
            let session = StubProtocol.session { _ in server.offline ? (-1, Data()) : (200, server.body) }
            let store = CredentialStore(store: MemoryStore())
            store.save(Credentials(clientID: "c1", accessToken: "a", refreshToken: "r", expiresAt: nil), for: address)
            var client = APIClient(server: address, auth: AuthSession(server: address, store: store, session: session), session: session)
            client.cache = cache
            client.onCacheUse = { uses.values.append($0) }
            return client
        }

        @Test func showsTheKeptAnswerWhenTheServerCantBeReached() async throws {
            let server = Server(), uses = Uses(), cache = temporaryCache()
            defer { cache.removeAll() }
            let api = try client(server, cache: cache, uses: uses)

            #expect(try await api.settings().timeZone == "Europe/Berlin")
            server.offline = true
            #expect(try await api.settings().timeZone == "Europe/Berlin")

            #expect(uses.values.count == 2)
            #expect(uses.values[0] == nil)
            #expect(uses.values[1] != nil)
        }

        @Test func withoutAKeptAnswerTheServerIsUnreachable() async throws {
            let server = Server(), uses = Uses(), cache = temporaryCache()
            server.offline = true
            let api = try client(server, cache: cache, uses: uses)
            await #expect(throws: APIError.self) { _ = try await api.settings() }
            #expect(uses.values.isEmpty)
        }

        @Test func changesAreNeverAnsweredFromTheCache() async throws {
            let server = Server(), uses = Uses(), cache = temporaryCache()
            defer { cache.removeAll() }
            let api = try client(server, cache: cache, uses: uses)
            _ = try await api.settings()
            server.offline = true
            await #expect(throws: APIError.self) { _ = try await api.updateSettings(.init(calmMode: true)) }
        }
    }
}
