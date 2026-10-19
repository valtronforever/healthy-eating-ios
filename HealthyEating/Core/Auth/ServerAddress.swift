import Foundation

/// A validated Healthy Eating server address, entered by the person during onboarding.
/// Nothing server-specific is compiled into the app; this is the only source of the host.
nonisolated struct ServerAddress: Equatable, Sendable {
    let baseURL: URL

    var host: String { baseURL.host() ?? baseURL.absoluteString }

    /// The MCP endpoint people paste into their AI assistant.
    var mcpURL: URL { baseURL.appending(path: "mcp") }

    enum ValidationError: Error, Equatable, Sendable {
        case empty
        case invalid
        case notHTTPS
    }

    /// `http://localhost` is accepted only in debug builds (see AGENTS.md, authentication flow).
    static var allowsInsecureLocalhost: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }

    /// Parses what the person typed. A missing scheme means https; http is rejected except
    /// for localhost when `allowInsecureLocalhost` is true.
    static func parse(_ input: String, allowInsecureLocalhost: Bool = allowsInsecureLocalhost) throws(ValidationError) -> ServerAddress {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw .empty }
        guard !trimmed.contains(where: \.isWhitespace) else { throw .invalid }

        let candidate = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard var components = URLComponents(string: candidate),
              let scheme = components.scheme?.lowercased(),
              let host = components.host?.lowercased(), !host.isEmpty,
              components.query == nil, components.fragment == nil,
              components.user == nil, components.password == nil
        else { throw .invalid }

        switch scheme {
        case "https":
            break
        case "http":
            let isLocal = ["localhost", "127.0.0.1", "::1", "[::1]"].contains(host)
            guard isLocal, allowInsecureLocalhost else { throw .notHTTPS }
        default:
            throw .invalid
        }

        components.scheme = scheme
        components.host = host
        while components.path.hasSuffix("/") {
            components.path.removeLast()
        }
        guard let url = components.url else { throw .invalid }
        return ServerAddress(baseURL: url)
    }
}

extension ServerAddress.ValidationError {
    /// User-facing message, written per the design system copy rules (calm, no alarm).
    nonisolated var message: String {
        switch self {
        case .empty: String(localized: "Enter the address of your server")
        case .invalid: String(localized: "Enter an address like https://food.example.com")
        case .notHTTPS: String(localized: "Use an https address")
        }
    }
}
