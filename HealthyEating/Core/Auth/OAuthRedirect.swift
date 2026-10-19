import Foundation

/// The OAuth redirect the app registers with each server through Dynamic Client Registration
/// (see AGENTS.md, authentication flow). The scheme is declared in `Info.plist`.
nonisolated enum OAuthRedirect {
    static let scheme = "healthyeating"
    static let callbackURL = "\(scheme)://oauth/callback"
}
