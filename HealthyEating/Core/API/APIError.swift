import Foundation

/// Everything that can go wrong talking to the server, mapped to calm user-facing copy in one
/// place. No red, no blame: state what happened and that the data is safe.
nonisolated enum APIError: Error, Equatable, Sendable {
    /// The session is over (refresh refused); the person signs in again.
    case sessionExpired
    /// The server did not answer.
    case unreachable(String)
    /// The meal, day mark or connection no longer exists.
    case notFound
    /// The server rejected the input; `fields` maps a field name to its problem.
    case invalid(message: String, fields: [String: String])
    /// Any other answer from the server, with its `{code, message}`.
    case server(code: String, message: String)
    /// The answer could not be read (an incompatible server version, for example).
    case unexpectedResponse(String)

    var message: String {
        switch self {
        case .sessionExpired:
            AuthError.sessionExpired.message
        case .unreachable:
            String(localized: "Can’t reach your server. Your data is safe on your server.")
        case .notFound:
            String(localized: "This item is no longer on your server.")
        case .invalid(let message, _):
            message
        case .server:
            String(localized: "Your server could not do this right now. Try again in a moment.")
        case .unexpectedResponse:
            String(localized: "Your server answered in a way this app does not understand. Check that the server and the app are up to date.")
        }
    }

    /// A technical detail for small print.
    var detail: String? {
        switch self {
        case .unreachable(let detail), .unexpectedResponse(let detail): detail
        case .server(let code, let message): "\(code): \(message)"
        default: nil
        }
    }

    init(_ error: AuthError) {
        switch error {
        case .unreachable(let detail): self = .unreachable(detail)
        default: self = .sessionExpired
        }
    }
}

/// The server's error body (`ErrorResponse` in openapi.json).
nonisolated struct ErrorResponseDTO: Decodable, Sendable {
    struct Detail: Decodable, Sendable {
        let field: String?
        let message: String
    }

    let code: String
    let message: String
    let details: [Detail]?
}
