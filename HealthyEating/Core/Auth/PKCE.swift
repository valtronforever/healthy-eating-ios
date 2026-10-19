import CryptoKit
import Foundation

/// Proof Key for Code Exchange (RFC 7636) with the S256 method, and the OAuth `state` value.
nonisolated struct PKCE: Sendable, Equatable {
    let verifier: String
    let challenge: String

    /// A fresh verifier from 32 random bytes (43 base64url characters) and its challenge.
    static func generate() -> PKCE {
        let verifier = randomString(byteCount: 32)
        return PKCE(verifier: verifier, challenge: challenge(for: verifier))
    }

    /// BASE64URL(SHA256(verifier)), without padding.
    static func challenge(for verifier: String) -> String {
        Data(SHA256.hash(data: Data(verifier.utf8))).base64URLEncodedString()
    }

    /// A random, URL-safe value, also used for `state`.
    static func randomString(byteCount: Int = 32) -> String {
        var generator = SystemRandomNumberGenerator()
        let bytes = (0..<byteCount).map { _ in UInt8.random(in: .min ... .max, using: &generator) }
        return Data(bytes).base64URLEncodedString()
    }
}

extension Data {
    nonisolated func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
