import Foundation
import Testing
@testable import HealthyEating

struct LinkCallbackTests {
    @Test func readsTheCode() throws {
        let url = try #require(URL(string: "healthyeating://link/callback?code=abc"))
        #expect(LinkCallback(url) == .code("abc"))
    }

    @Test func readsCancelAndExpiry() throws {
        #expect(LinkCallback(try #require(URL(string: "healthyeating://link/callback?error=cancelled"))) == .cancelled)
        #expect(LinkCallback(try #require(URL(string: "healthyeating://link/callback?error=expired"))) == .expired)
    }

    @Test func ignoresOtherRedirects() throws {
        #expect(LinkCallback(try #require(URL(string: "healthyeating://oauth/callback?code=abc"))) == nil)
        #expect(LinkCallback(try #require(URL(string: "healthyeating://link/callback?code="))) == nil)
        #expect(LinkCallback(try #require(URL(string: "https://link/callback?code=abc"))) == nil)
    }
}

struct LinkedAccountsWordingTests {
    private let locale = Locale(identifier: "en_US")
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }

    @Test func namesEachProviderOnce() {
        #expect(Account(linkedLogins: ["google", "google", "microsoft"]).loginsText == "Google and Microsoft")
    }

    @Test func saysWhenALoginWasLastUsedOrAdded() {
        let now = Date(timeIntervalSince1970: 1_792_900_000)  // 2026-10-25 03:46 UTC
        let used = Login(id: UUID(), provider: "google", email: nil, createdAt: now, lastLoginAt: now.addingTimeInterval(-7200))
        let unused = Login(id: UUID(), provider: "apple", email: nil, createdAt: Date(timeIntervalSince1970: 1_792_700_000), lastLoginAt: nil)

        #expect(LinkedAccountsView.detail(used, now: now, calendar: calendar, locale: locale) == "Last sign-in 2 h ago")
        #expect(LinkedAccountsView.detail(unused, now: now, calendar: calendar, locale: locale) == "Added Oct 22, 2026")
    }

    @Test func notesAreNeutralAndNameTheNewLogin() {
        let added = Login(id: UUID(), provider: "microsoft", email: nil, createdAt: .now, lastLoginAt: nil)
        #expect(LinkedAccountsView.notice(for: .linked, added: added) == "Microsoft account linked. You can sign in with it from now on.")
        #expect(LinkedAccountsView.notice(for: .otherAccount, added: nil)?.contains("never merged") == true)
        #expect(LinkedAccountsView.notice(for: .cancelled, added: nil) == nil)
    }
}

/// Returns a fixed redirect (or error) instead of opening the web sheet.
@MainActor
private struct StubAuthenticator: WebAuthenticating {
    var result: Result<URL, AuthError>
    func authenticate(url: URL, callbackScheme: String) async throws(AuthError) -> URL {
        try result.get()
    }
}

@MainActor
struct LoginLinkingSampleTests {
    @Test func addsALoginAndLeavesItOutWhenCancelled() async throws {
        let data = SampleDataSource()
        let code = try #require(URL(string: "healthyeating://link/callback?code=x"))

        let cancelled = try await LoginLinking.addLogin(data: data, authenticator: StubAuthenticator(result: .failure(.cancelled)))
        let cancelledOnPage = try await LoginLinking.addLogin(
            data: data, authenticator: StubAuthenticator(result: .success(try #require(URL(string: "healthyeating://link/callback?error=cancelled")))))
        let countBefore = await data.logins().count
        let linked = try await LoginLinking.addLogin(data: data, authenticator: StubAuthenticator(result: .success(code)))

        #expect(cancelled == .cancelled)
        #expect(cancelledOnPage == .cancelled)
        #expect(linked == .linked)
        #expect(await data.logins().count == countBefore + 1)
    }

    @Test func anExpiredPageAsksToStartAgain() async throws {
        let expired = try #require(URL(string: "healthyeating://link/callback?error=expired"))
        await #expect(throws: APIError.self) {
            _ = try await LoginLinking.addLogin(data: SampleDataSource(), authenticator: StubAuthenticator(result: .success(expired)))
        }
    }
}

extension NetworkTests {
    @MainActor
    struct LinkedAccountsAPITests {
        private func api(_ handler: @escaping @Sendable (URLRequest) -> (Int, Data)) throws -> APIClient {
            let server = try ServerAddress.parse("https://food.example.com")
            let session = StubProtocol.session(handler)
            let store = CredentialStore(store: MemoryStore())
            store.save(Credentials(clientID: "c1", accessToken: "a", refreshToken: "r", expiresAt: nil), for: server)
            return APIClient(server: server, auth: AuthSession(server: server, store: store, session: session), session: session)
        }

        private static func body(_ request: URLRequest) -> [String: String] {
            (try? JSONSerialization.jsonObject(with: request.httpBody ?? Data())) as? [String: String] ?? [:]
        }

        @Test func mapsLogins() async throws {
            let api = try api { _ in
                (200, Data(#"{"logins":[{"id":"0b6f3c2e-1111-4000-8000-000000000001","provider":"google","email":"a@example.com","created_at":"2026-10-20T08:00:00Z","last_login_at":null}]}"#.utf8))
            }
            let logins = try await api.logins()
            #expect(StubProtocol.requests.last?.url?.path() == "/api/v1/me/logins")
            #expect(logins.map(\.providerName) == ["Google"])
            #expect(logins.first?.lastLoginAt == nil)
        }

        /// The whole flow against the server: the verifier sent at the end matches the challenge
        /// sent at the start, and the code comes from the web sheet's redirect.
        @Test func linksWithPKCE() async throws {
            let api = try api { request in
                switch request.url?.path() {
                case "/api/v1/me/logins/link":
                    (201, Data(#"{"url":"https://food.example.com/link?request=r1","expires_at":"2026-10-25T06:00:00Z"}"#.utf8))
                default:
                    (200, Data(#"{"result":"linked"}"#.utf8))
                }
            }
            let redirect = try #require(URL(string: "healthyeating://link/callback?code=done"))

            let result = try await LoginLinking.addLogin(data: api, authenticator: StubAuthenticator(result: .success(redirect)))

            #expect(result == .linked)
            let start = try #require(StubProtocol.requests.first { $0.url?.path() == "/api/v1/me/logins/link" })
            let complete = try #require(StubProtocol.requests.last)
            #expect(complete.url?.path() == "/api/v1/me/logins/link/complete")
            #expect(Self.body(start)["code_challenge_method"] == "S256")
            #expect(Self.body(complete)["code"] == "done")
            let verifier = try #require(Self.body(complete)["code_verifier"])
            #expect(PKCE.challenge(for: verifier) == Self.body(start)["code_challenge"])
        }

        @Test func aLoginOfAnotherAccountIsNotAnError() async throws {
            let api = try api { _ in (409, Data(#"{"code":"conflict","message":"other account","details":null}"#.utf8)) }
            #expect(try await api.completeLink(code: "c", verifier: "v") == .otherAccount)
        }

        @Test func aUsedCodeAsksToStartAgain() async throws {
            let api = try api { _ in (400, Data(#"{"code":"bad_request","message":"used","details":null}"#.utf8)) }
            await #expect(throws: APIError.invalid(message: "This took too long or was already used. Try linking the account again.", fields: [:])) {
                _ = try await api.completeLink(code: "c", verifier: "v")
            }
        }

        @Test func theOnlyLoginStays() async throws {
            let api = try api { _ in (409, Data(#"{"code":"conflict","message":"only login","details":null}"#.utf8)) }
            let id = UUID()
            await #expect(throws: APIError.invalid(message: "This is the only account you sign in with, so it stays linked.", fields: [:])) {
                try await api.deleteLogin(id)
            }
            #expect(StubProtocol.requests.last?.httpMethod == "DELETE")
            #expect(StubProtocol.requests.last?.url?.path() == "/api/v1/me/logins/\(id.uuidString.lowercased())")
        }
    }
}
