import Foundation

/// Signs in to a server: discovery, Dynamic Client Registration (once per server), the web
/// sheet with PKCE and `state`, then the code exchange. Tokens go to the Keychain only.
@MainActor
protocol SignInProviding {
    func signIn(to server: ServerAddress, store: CredentialStore) async throws(AuthError) -> Credentials
}

@MainActor
struct OAuthSignIn: SignInProviding {
    var authenticator: any WebAuthenticating = SystemWebAuthenticator()
    var session: URLSession = .shared

    func signIn(to server: ServerAddress, store: CredentialStore) async throws(AuthError) -> Credentials {
        let client = OAuthClient(server: server, session: session)
        let metadata = try await client.discover()
        let clientID: String
        if let registered = store.clientID(for: server) {
            clientID = registered
        } else {
            clientID = try await client.register(with: metadata)
            store.saveClientID(clientID, for: server)
        }
        let pkce = PKCE.generate()
        let state = PKCE.randomString(byteCount: 16)
        let url = client.authorizationURL(metadata: metadata, clientID: clientID, pkce: pkce, state: state)
        let callback = try await authenticator.authenticate(url: url, callbackScheme: OAuthRedirect.scheme)
        let code = try OAuthClient.authorizationCode(from: callback, expectedState: state)
        let tokens = try await client.exchange(code: code, verifier: pkce.verifier, clientID: clientID, metadata: metadata)
        let credentials = Credentials(clientID: clientID, response: tokens)
        store.save(credentials, for: server)
        return credentials
    }
}

/// UI tests and screenshots: signs in at once with placeholder credentials, no network.
@MainActor
struct PlaceholderSignIn: SignInProviding {
    func signIn(to server: ServerAddress, store: CredentialStore) async throws(AuthError) -> Credentials {
        let credentials = Credentials(clientID: "placeholder", accessToken: "placeholder", refreshToken: nil, expiresAt: nil)
        store.save(credentials, for: server)
        return credentials
    }
}

/// The signed-in session for one server: hands out access tokens, refreshing them when they
/// expire or the server rejects them. Concurrent callers share one refresh.
actor AuthSession {
    let server: ServerAddress
    private let store: CredentialStore
    private let client: OAuthClient
    private var metadata: AuthorizationServerMetadata?
    private var refreshTask: Task<Credentials, any Error>?

    init(server: ServerAddress, store: CredentialStore, session: URLSession = .shared) {
        self.server = server
        self.store = store
        self.client = OAuthClient(server: server, session: session)
    }

    /// A token for the next request; refreshed first when it is about to expire.
    func accessToken() async throws(AuthError) -> String {
        guard let credentials = store.credentials(for: server) else { throw .sessionExpired }
        if credentials.isAccessTokenFresh() { return credentials.accessToken }
        return try await refresh(rejected: credentials.accessToken)
    }

    /// Call after a 401 with the token that was rejected. If another request already refreshed
    /// it, the new token is returned without a second refresh.
    func refresh(rejected token: String) async throws(AuthError) -> String {
        if let current = store.credentials(for: server), current.accessToken != token, current.isAccessTokenFresh() {
            return current.accessToken
        }
        let task: Task<Credentials, any Error>
        if let running = refreshTask {
            task = running
        } else {
            task = Task { try await self.performRefresh() }
            refreshTask = task
        }
        defer { if refreshTask == task { refreshTask = nil } }
        do {
            return try await task.value.accessToken
        } catch let error as AuthError {
            throw error
        } catch {
            throw .sessionExpired
        }
    }

    private func performRefresh() async throws(AuthError) -> Credentials {
        guard let credentials = store.credentials(for: server), let refreshToken = credentials.refreshToken else {
            throw .sessionExpired
        }
        let metadata = try await serverMetadata()
        do {
            let tokens = try await client.refresh(refreshToken: refreshToken, clientID: credentials.clientID, metadata: metadata)
            let updated = credentials.updated(with: tokens)
            store.save(updated, for: server)
            return updated
        } catch .unreachable(let detail) {
            throw .unreachable(detail)
        } catch {
            // The server refused the refresh token: the grant is over.
            store.delete(for: server)
            throw .sessionExpired
        }
    }

    /// Revokes the grant on the server (best effort) and forgets the tokens.
    func signOut() async {
        if let credentials = store.credentials(for: server), let metadata = try? await serverMetadata() {
            let token = credentials.refreshToken ?? credentials.accessToken
            try? await client.revoke(token: token, clientID: credentials.clientID, metadata: metadata)
        }
        store.delete(for: server)
    }

    private func serverMetadata() async throws(AuthError) -> AuthorizationServerMetadata {
        if let metadata { return metadata }
        let discovered = try await client.discover()
        metadata = discovered
        return discovered
    }
}
