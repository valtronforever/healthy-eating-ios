import Foundation

/// Adds another social login to the signed-in account (#20), like an authorization code with
/// PKCE: the server returns a page for the challenge, the person signs in there in the web
/// sheet, the page returns to `healthyeating://link/callback` with a one-time code, and the app
/// finishes with that code and its verifier. A forwarded page can't be finished elsewhere.
@MainActor
enum LoginLinking {
    static func addLogin(data: any NutritionDataSource, authenticator: any WebAuthenticating) async throws(APIError) -> LinkResult {
        let pkce = PKCE.generate()
        let page = try await data.startLink(challenge: pkce.challenge)
        let callback: URL
        do {
            callback = try await authenticator.authenticate(url: page, callbackScheme: OAuthRedirect.scheme)
        } catch .cancelled {
            return .cancelled
        } catch {
            throw .invalid(message: error.message, fields: [:])
        }
        switch LinkCallback(callback) {
        case .code(let code):
            return try await data.completeLink(code: code, verifier: pkce.verifier)
        case .cancelled:
            return .cancelled
        case .expired, nil:
            throw .invalid(message: String(localized: "This took too long or was already used. Try linking the account again."), fields: [:])
        }
    }
}

/// Where the server's link page sends the browser: `?code=`, or `?error=cancelled|expired`.
nonisolated enum LinkCallback: Equatable {
    static let url = "\(OAuthRedirect.scheme)://link/callback"

    case code(String)
    case cancelled
    case expired

    init?(_ url: URL) {
        guard url.scheme == OAuthRedirect.scheme, url.host() == "link", url.path() == "/callback",
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
        else { return nil }
        if let code = items.first(where: { $0.name == "code" })?.value, !code.isEmpty {
            self = .code(code)
            return
        }
        switch items.first(where: { $0.name == "error" })?.value {
        case "cancelled": self = .cancelled
        case "expired": self = .expired
        default: return nil
        }
    }
}

/// UI tests and screenshots: the web sheet "signs in" at once, without network.
@MainActor
struct PlaceholderWebAuthenticator: WebAuthenticating {
    func authenticate(url: URL, callbackScheme: String) async throws(AuthError) -> URL {
        URL(string: "\(LinkCallback.url)?code=placeholder") ?? url
    }
}
