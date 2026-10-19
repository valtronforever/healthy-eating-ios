import AuthenticationServices
import UIKit

/// Opens the server's login page in the system web sheet (A3) and returns the redirect URL.
@MainActor
protocol WebAuthenticating {
    func authenticate(url: URL, callbackScheme: String) async throws(AuthError) -> URL
}

/// `ASWebAuthenticationSession`. It shares cookies with Safari, so a person already signed in
/// to Google or Microsoft there does not have to type their password again.
@MainActor
final class SystemWebAuthenticator: NSObject, WebAuthenticating, ASWebAuthenticationPresentationContextProviding {
    private var session: ASWebAuthenticationSession?

    func authenticate(url: URL, callbackScheme: String) async throws(AuthError) -> URL {
        let result: Result<URL, AuthError> = await withCheckedContinuation { continuation in
            let session = ASWebAuthenticationSession(url: url, callback: .customScheme(callbackScheme)) { url, error in
                if let url {
                    continuation.resume(returning: .success(url))
                } else if (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin {
                    continuation.resume(returning: .failure(.cancelled))
                } else {
                    continuation.resume(returning: .failure(.signInFailed(error?.localizedDescription ?? "no redirect")))
                }
            }
            session.presentationContextProvider = self
            if !session.start() {
                continuation.resume(returning: .failure(.signInFailed("the sign-in sheet could not open")))
            }
            self.session = session
        }
        session = nil
        return try result.get()
    }

    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            let windows = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows)
            return windows.first(where: \.isKeyWindow) ?? windows.first ?? ASPresentationAnchor()
        }
    }
}
