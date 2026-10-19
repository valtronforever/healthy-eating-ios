import Foundation

/// Talks to a Healthy Eating server's OAuth endpoints: discovery, Dynamic Client Registration,
/// the authorization URL, token exchange, refresh and revocation. The same flow MCP clients use.
nonisolated struct OAuthClient: Sendable {
    static let scope = "nutrition"
    static let clientName = "Healthy Eating for iOS"

    let server: ServerAddress
    var session: URLSession = .shared

    func discover() async throws(AuthError) -> AuthorizationServerMetadata {
        let url = server.baseURL.appending(path: ".well-known/oauth-authorization-server")
        let data = try await send(URLRequest(url: url), expecting: 200, otherwise: .notAHealthyEatingServer)
        do {
            return try JSONDecoder().decode(AuthorizationServerMetadata.self, from: data)
        } catch {
            throw .notAHealthyEatingServer
        }
    }

    /// Registers the app as a public native client and returns its `client_id`.
    func register(with metadata: AuthorizationServerMetadata) async throws(AuthError) -> String {
        guard let endpoint = metadata.registrationEndpoint else { throw .notAHealthyEatingServer }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "client_name": Self.clientName,
            "redirect_uris": [OAuthRedirect.callbackURL],
            "application_type": "native",
            "token_endpoint_auth_method": "none",
            "grant_types": ["authorization_code", "refresh_token"],
            "response_types": ["code"],
            "scope": Self.scope,
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        let data = try await send(request, expecting: 201, otherwise: .signInFailed("registration refused"))
        struct Registration: Decodable { let client_id: String }
        do {
            return try JSONDecoder().decode(Registration.self, from: data).client_id
        } catch {
            throw .signInFailed("registration response unreadable")
        }
    }

    func authorizationURL(
        metadata: AuthorizationServerMetadata, clientID: String, pkce: PKCE, state: String
    ) -> URL {
        metadata.authorizationEndpoint.appending(queryItems: [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: OAuthRedirect.callbackURL),
            URLQueryItem(name: "code_challenge", value: pkce.challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "scope", value: Self.scope),
            URLQueryItem(name: "resource", value: server.mcpURL.absoluteString),
        ])
    }

    /// Reads the authorization code from the redirect, checking `state`.
    static func authorizationCode(from callback: URL, expectedState: String) throws(AuthError) -> String {
        let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let value = { (name: String) in items.first { $0.name == name }?.value }
        if let error = value("error") {
            throw error == "access_denied" ? .cancelled : .signInFailed(error)
        }
        guard value("state") == expectedState else { throw .signInFailed("state mismatch") }
        guard let code = value("code"), !code.isEmpty else { throw .signInFailed("no code") }
        return code
    }

    func exchange(
        code: String, verifier: String, clientID: String, metadata: AuthorizationServerMetadata
    ) async throws(AuthError) -> TokenResponse {
        try await token(metadata: metadata, form: [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": OAuthRedirect.callbackURL,
            "client_id": clientID,
            "code_verifier": verifier,
        ], otherwise: .signInFailed("code exchange refused"))
    }

    func refresh(
        refreshToken: String, clientID: String, metadata: AuthorizationServerMetadata
    ) async throws(AuthError) -> TokenResponse {
        try await token(metadata: metadata, form: [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": clientID,
        ], otherwise: .sessionExpired)
    }

    /// Revokes the token's whole grant. The server requires a `client_secret` field even for
    /// public clients, so an empty one is sent.
    func revoke(token: String, clientID: String, metadata: AuthorizationServerMetadata) async throws(AuthError) {
        guard let endpoint = metadata.revocationEndpoint else { return }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.formBody(["token": token, "client_id": clientID, "client_secret": ""])
        _ = try await send(request, expecting: 200, otherwise: .signInFailed("revocation refused"))
    }

    // MARK: - Helpers

    private func token(
        metadata: AuthorizationServerMetadata, form: [String: String], otherwise failure: AuthError
    ) async throws(AuthError) -> TokenResponse {
        var request = URLRequest(url: metadata.tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.formBody(form)
        let data = try await send(request, expecting: 200, otherwise: failure)
        do {
            return try JSONDecoder().decode(TokenResponse.self, from: data)
        } catch {
            throw failure
        }
    }

    private func send(_ request: URLRequest, expecting status: Int, otherwise failure: AuthError) async throws(AuthError) -> Data {
        var request = request
        request.timeoutInterval = 15
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw .unreachable((error as? URLError)?.localizedDescription ?? error.localizedDescription)
        }
        guard (response as? HTTPURLResponse)?.statusCode == status else { throw failure }
        return data
    }

    static func formBody(_ fields: [String: String]) -> Data {
        var components = URLComponents()
        components.queryItems = fields.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        // URLComponents leaves "+" unescaped, which form decoding reads as a space.
        let encoded = (components.percentEncodedQuery ?? "").replacingOccurrences(of: "+", with: "%2B")
        return Data(encoded.utf8)
    }
}
