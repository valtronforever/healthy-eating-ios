import Foundation

/// The server's OAuth endpoints, from `/.well-known/oauth-authorization-server` (RFC 8414).
nonisolated struct AuthorizationServerMetadata: Decodable, Sendable, Equatable {
    let issuer: URL
    let authorizationEndpoint: URL
    let tokenEndpoint: URL
    let registrationEndpoint: URL?
    let revocationEndpoint: URL?

    enum CodingKeys: String, CodingKey {
        case issuer
        case authorizationEndpoint = "authorization_endpoint"
        case tokenEndpoint = "token_endpoint"
        case registrationEndpoint = "registration_endpoint"
        case revocationEndpoint = "revocation_endpoint"
    }
}

/// A `/token` response.
nonisolated struct TokenResponse: Decodable, Sendable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }
}

/// What the app keeps per server, in the Keychain only: its registered client and the tokens.
nonisolated struct Credentials: Codable, Sendable, Equatable {
    var clientID: String
    var accessToken: String
    var refreshToken: String?
    var expiresAt: Date?

    init(clientID: String, accessToken: String, refreshToken: String?, expiresAt: Date?) {
        self.clientID = clientID
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
    }

    init(clientID: String, response: TokenResponse, now: Date = .now) {
        self.init(
            clientID: clientID,
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            expiresAt: response.expiresIn.map { now.addingTimeInterval(TimeInterval($0)) })
    }

    /// Treat the token as expired a minute early, so a request never races the expiry.
    func isAccessTokenFresh(now: Date = .now) -> Bool {
        guard let expiresAt else { return true }
        return expiresAt.timeIntervalSince(now) > 60
    }

    func updated(with response: TokenResponse, now: Date = .now) -> Credentials {
        Credentials(
            clientID: clientID,
            accessToken: response.accessToken,
            refreshToken: response.refreshToken ?? refreshToken,
            expiresAt: response.expiresIn.map { now.addingTimeInterval(TimeInterval($0)) })
    }
}

/// Why signing in or keeping a session failed. Mapped to calm, user-facing copy in one place.
nonisolated enum AuthError: Error, Equatable, Sendable {
    /// The server did not answer (offline, wrong address, server down).
    case unreachable(String)
    /// The address answers, but not like a Healthy Eating server.
    case notAHealthyEatingServer
    /// The person closed the sign-in sheet.
    case cancelled
    /// The server refused the sign-in (for example the login request expired).
    case signInFailed(String)
    /// The refresh token no longer works; the person has to sign in again.
    case sessionExpired

    var message: String {
        switch self {
        case .unreachable:
            String(localized: "Can’t reach your server. Check that it is running and that you are online.")
        case .notAHealthyEatingServer:
            String(localized: "This address does not look like a Healthy Eating server. Check the address.")
        case .cancelled:
            String(localized: "Sign-in was cancelled.")
        case .signInFailed:
            String(localized: "Sign-in did not finish. Try again.")
        case .sessionExpired:
            String(localized: "Your session ended. Sign in again to see your data.")
        }
    }

    /// A technical detail for the small print, if any.
    var detail: String? {
        switch self {
        case .unreachable(let detail), .signInFailed(let detail): detail
        default: nil
        }
    }
}
