import Foundation
import Testing
@testable import HealthyEating

struct OAuthRedirectTests {
    @Test func appDeclaresTheCallbackScheme() throws {
        let types = try #require(Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]])
        let schemes = types.flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] }
        #expect(schemes.contains(OAuthRedirect.scheme))
    }

    @Test func callbackURLMatchesTheDocumentedRedirect() throws {
        let url = try #require(URL(string: OAuthRedirect.callbackURL))
        #expect(url.scheme == "healthyeating")
        #expect(url.host() == "oauth")
        #expect(url.path() == "/callback")
    }

    @Test func generatedKeysAreStillMerged() {
        #expect(Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String == "Healthy Eating")
    }
}
