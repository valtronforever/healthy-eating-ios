import Foundation
import Testing
@testable import HealthyEating

/// Answers requests of a test's own URLSession from a closure, so OAuth calls run without a server.
final class StubProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) -> (Int, Data))?
    nonisolated(unsafe) static var requests: [URLRequest] = []

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        var request = request
        if request.httpBody == nil, let stream = request.httpBodyStream {
            stream.open()
            var data = Data()
            var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                if count <= 0 { break }
                data.append(buffer, count: count)
            }
            stream.close()
            request.httpBody = data
        }
        Self.requests.append(request)
        let (status, body) = Self.handler?(request) ?? (500, Data())
        // A negative status stands for a network failure (no answer at all).
        guard status >= 0 else {
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
            return
        }
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    static func session(_ handler: @escaping @Sendable (URLRequest) -> (Int, Data)) -> URLSession {
        self.handler = handler
        requests = []
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubProtocol.self]
        return URLSession(configuration: configuration)
    }
}

private let server = try! ServerAddress.parse("https://food.example.com")

private let metadataJSON = Data("""
{"issuer":"https://food.example.com/","authorization_endpoint":"https://food.example.com/authorize",
 "token_endpoint":"https://food.example.com/token","registration_endpoint":"https://food.example.com/register",
 "revocation_endpoint":"https://food.example.com/revoke"}
""".utf8)

private func form(_ request: URLRequest) -> [String: String] {
    let body = String(data: request.httpBody ?? Data(), encoding: .utf8) ?? ""
    var components = URLComponents()
    components.percentEncodedQuery = body
    return Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
}

private func tokens(_ access: String, refresh: String = "refresh-2", expiresIn: Int = 3600) -> Data {
    Data(#"{"access_token":"\#(access)","refresh_token":"\#(refresh)","expires_in":\#(expiresIn),"token_type":"Bearer"}"#.utf8)
}

struct PKCETests {
    @Test func verifierAndChallengeFollowRFC7636() {
        // The example from RFC 7636, appendix B.
        #expect(PKCE.challenge(for: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk")
            == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
        let pkce = PKCE.generate()
        #expect(pkce.verifier.count == 43)
        #expect(pkce.verifier.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" })
        #expect(pkce.challenge == PKCE.challenge(for: pkce.verifier))
        #expect(PKCE.generate().verifier != pkce.verifier)
    }

    @Test func formBodiesEscapePlusSigns() {
        let body = String(decoding: OAuthClient.formBody(["code": "a+b c", "client_secret": ""]), as: UTF8.self)
        #expect(body == "client_secret=&code=a%2Bb%20c")
    }
}

struct AuthorizationRedirectTests {
    @Test func readsTheCodeWhenStateMatches() throws {
        let url = try #require(URL(string: "healthyeating://oauth/callback?code=abc&state=s1"))
        #expect(try OAuthClient.authorizationCode(from: url, expectedState: "s1") == "abc")
    }

    @Test func rejectsAnotherState() throws {
        let url = try #require(URL(string: "healthyeating://oauth/callback?code=abc&state=other"))
        #expect(throws: AuthError.signInFailed("state mismatch")) {
            try OAuthClient.authorizationCode(from: url, expectedState: "s1")
        }
    }

    @Test func accessDeniedMeansCancelled() throws {
        let url = try #require(URL(string: "healthyeating://oauth/callback?error=access_denied&state=s1"))
        #expect(throws: AuthError.cancelled) { try OAuthClient.authorizationCode(from: url, expectedState: "s1") }
    }

    @Test func authorizationURLCarriesPKCEStateScopeAndResource() throws {
        let metadata = try JSONDecoder().decode(AuthorizationServerMetadata.self, from: metadataJSON)
        let pkce = PKCE.generate()
        let url = OAuthClient(server: server).authorizationURL(metadata: metadata, clientID: "c1", pkce: pkce, state: "s1")
        let items = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        let query = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
        #expect(url.path() == "/authorize")
        #expect(query["response_type"] == "code")
        #expect(query["client_id"] == "c1")
        #expect(query["redirect_uri"] == "healthyeating://oauth/callback")
        #expect(query["code_challenge"] == pkce.challenge)
        #expect(query["code_challenge_method"] == "S256")
        #expect(query["state"] == "s1")
        #expect(query["scope"] == "nutrition")
        #expect(query["resource"] == "https://food.example.com/mcp")
    }
}

struct CredentialStoreTests {
    @Test(arguments: [false, true])
    func storesTokensPerServerAndKeepsTheClientOnDelete(useKeychain: Bool) throws {
        let store = CredentialStore(store: useKeychain ? Keychain(service: "HealthyEatingTests.\(UUID())") : MemoryStore())
        let other = try ServerAddress.parse("https://other.example.com")
        let credentials = Credentials(clientID: "c1", accessToken: "a", refreshToken: "r", expiresAt: nil)
        #expect(store.save(credentials, for: server))
        store.saveClientID("c1", for: server)
        #expect(store.credentials(for: server) == credentials)
        #expect(store.credentials(for: other) == nil)

        store.delete(for: server)
        #expect(store.credentials(for: server) == nil)
        #expect(store.clientID(for: server) == "c1")
        store.store.delete("client:\(server.baseURL.absoluteString)")
    }

    @Test func freshnessLeavesAMinuteOfMargin() {
        let now = Date(timeIntervalSince1970: 1_000)
        #expect(Credentials(clientID: "c", accessToken: "a", refreshToken: nil, expiresAt: now.addingTimeInterval(120)).isAccessTokenFresh(now: now))
        #expect(!Credentials(clientID: "c", accessToken: "a", refreshToken: nil, expiresAt: now.addingTimeInterval(30)).isAccessTokenFresh(now: now))
        #expect(Credentials(clientID: "c", accessToken: "a", refreshToken: nil, expiresAt: nil).isAccessTokenFresh(now: now))
    }
}

/// Every test that uses `StubProtocol` (one global handler) runs inside this suite, one at a time.
@Suite(.serialized)
struct NetworkTests {}

extension NetworkTests {
struct OAuthNetworkTests {
    @Test func discoversRegistersAndExchanges() async throws {
        let session = StubProtocol.session { request in
            switch request.url?.path() {
            case "/.well-known/oauth-authorization-server": (200, metadataJSON)
            case "/register": (201, Data(#"{"client_id":"client-1"}"#.utf8))
            case "/token": (200, tokens("access-1", refresh: "refresh-1"))
            default: (404, Data())
            }
        }
        let client = OAuthClient(server: server, session: session)
        let metadata = try await client.discover()
        #expect(try await client.register(with: metadata) == "client-1")
        let response = try await client.exchange(code: "code-1", verifier: "v", clientID: "client-1", metadata: metadata)
        #expect(response.accessToken == "access-1")

        let registration = try #require(StubProtocol.requests.first { $0.url?.path() == "/register" })
        let body = try #require(JSONSerialization.jsonObject(with: registration.httpBody ?? Data()) as? [String: Any])
        #expect(body["redirect_uris"] as? [String] == ["healthyeating://oauth/callback"])
        #expect(body["token_endpoint_auth_method"] as? String == "none")
        #expect(body["application_type"] as? String == "native")
        let exchange = form(try #require(StubProtocol.requests.last))
        #expect(exchange == [
            "grant_type": "authorization_code", "code": "code-1", "code_verifier": "v",
            "client_id": "client-1", "redirect_uri": "healthyeating://oauth/callback",
        ])
    }

    @Test func aServerWithoutOAuthMetadataIsNotAHealthyEatingServer() async {
        let session = StubProtocol.session { _ in (404, Data("<html>".utf8)) }
        await #expect(throws: AuthError.notAHealthyEatingServer) {
            try await OAuthClient(server: server, session: session).discover()
        }
    }

    @Test func concurrentRequestsShareOneRefresh() async throws {
        let session = StubProtocol.session { request in
            switch request.url?.path() {
            case "/.well-known/oauth-authorization-server": (200, metadataJSON)
            case "/token": (200, tokens("access-2"))
            default: (404, Data())
            }
        }
        let store = CredentialStore(store: MemoryStore())
        store.save(Credentials(clientID: "c1", accessToken: "access-1", refreshToken: "refresh-1", expiresAt: nil), for: server)
        let auth = AuthSession(server: server, store: store, session: session)

        async let first = auth.refresh(rejected: "access-1")
        async let second = auth.refresh(rejected: "access-1")
        let results = try await [first, second]

        #expect(results == ["access-2", "access-2"])
        #expect(StubProtocol.requests.filter { $0.url?.path() == "/token" }.count == 1)
        #expect(store.credentials(for: server)?.refreshToken == "refresh-2")
        // A request that still holds the old token gets the new one without another refresh.
        #expect(try await auth.refresh(rejected: "access-1") == "access-2")
        #expect(StubProtocol.requests.filter { $0.url?.path() == "/token" }.count == 1)
    }

    @Test func aRefusedRefreshEndsTheSession() async {
        let session = StubProtocol.session { request in
            request.url?.path() == "/token" ? (401, Data(#"{"error":"invalid_grant"}"#.utf8)) : (200, metadataJSON)
        }
        let store = CredentialStore(store: MemoryStore())
        store.save(Credentials(clientID: "c1", accessToken: "a", refreshToken: "r", expiresAt: .distantPast), for: server)
        let auth = AuthSession(server: server, store: store, session: session)
        await #expect(throws: AuthError.sessionExpired) { try await auth.accessToken() }
        #expect(store.credentials(for: server) == nil)
    }

    @Test func signOutRevokesWithAnEmptySecretAndForgetsTokens() async throws {
        let session = StubProtocol.session { request in
            request.url?.path() == "/revoke" ? (200, Data()) : (200, metadataJSON)
        }
        let store = CredentialStore(store: MemoryStore())
        store.save(Credentials(clientID: "c1", accessToken: "a", refreshToken: "r", expiresAt: nil), for: server)
        await AuthSession(server: server, store: store, session: session).signOut()
        let revoke = form(try #require(StubProtocol.requests.last))
        #expect(revoke == ["token": "r", "client_id": "c1", "client_secret": ""])
        #expect(store.credentials(for: server) == nil)
    }

    @Test @MainActor func signInRunsTheWholeFlowAndReusesTheClient() async throws {
        let session = StubProtocol.session { request in
            switch request.url?.path() {
            case "/.well-known/oauth-authorization-server": (200, metadataJSON)
            case "/register": (201, Data(#"{"client_id":"client-1"}"#.utf8))
            case "/token":
                form(request)["code"] == "the-code" ? (200, tokens("access-1")) : (400, Data())
            default: (404, Data())
            }
        }
        let store = CredentialStore(store: MemoryStore())
        let signIn = OAuthSignIn(authenticator: EchoAuthenticator(code: "the-code"), session: session)

        let credentials = try await signIn.signIn(to: server, store: store)
        #expect(credentials.accessToken == "access-1")
        #expect(store.credentials(for: server)?.clientID == "client-1")

        store.delete(for: server)
        _ = try await signIn.signIn(to: server, store: store)
        #expect(StubProtocol.requests.filter { $0.url?.path() == "/register" }.count == 1)
    }
}

}

/// Plays the server's login page: redirects at once with a code and the request's `state`.
@MainActor
struct EchoAuthenticator: WebAuthenticating {
    let code: String

    func authenticate(url: URL, callbackScheme: String) async throws(AuthError) -> URL {
        let state = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "state" }?.value ?? ""
        return URL(string: "\(callbackScheme)://oauth/callback?code=\(code)&state=\(state)")!
    }
}
