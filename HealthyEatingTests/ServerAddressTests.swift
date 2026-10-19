import Foundation
import Testing
@testable import HealthyEating

struct ServerAddressTests {
    @Test func acceptsHTTPSAndBuildsMCPURL() throws {
        let address = try ServerAddress.parse("https://food.example.com")
        #expect(address.host == "food.example.com")
        #expect(address.mcpURL.absoluteString == "https://food.example.com/mcp")
    }

    @Test func addsHTTPSWhenSchemeIsMissing() throws {
        let address = try ServerAddress.parse("  Food.Example.com/  ")
        #expect(address.baseURL.absoluteString == "https://food.example.com")
    }

    @Test func keepsSubpathWithoutTrailingSlash() throws {
        let address = try ServerAddress.parse("https://example.com/healthy/")
        #expect(address.mcpURL.absoluteString == "https://example.com/healthy/mcp")
    }

    @Test func rejectsPlainHTTP() {
        #expect(throws: ServerAddress.ValidationError.notHTTPS) {
            try ServerAddress.parse("http://food.example.com", allowInsecureLocalhost: true)
        }
    }

    @Test func allowsLocalhostOnlyWhenPermitted() throws {
        let address = try ServerAddress.parse("http://localhost:8000", allowInsecureLocalhost: true)
        #expect(address.mcpURL.absoluteString == "http://localhost:8000/mcp")
        #expect(throws: ServerAddress.ValidationError.notHTTPS) {
            try ServerAddress.parse("http://localhost:8000", allowInsecureLocalhost: false)
        }
    }

    @Test(arguments: ["", "   "])
    func rejectsEmptyInput(_ input: String) {
        #expect(throws: ServerAddress.ValidationError.empty) { try ServerAddress.parse(input) }
    }

    @Test(arguments: ["food example.com", "ftp://food.example.com", "https://food.example.com?x=1", "https://user:pw@food.example.com", "https://"])
    func rejectsInvalidInput(_ input: String) {
        #expect(throws: ServerAddress.ValidationError.invalid) { try ServerAddress.parse(input) }
    }

    @Test func errorMessagesAreCalm() {
        #expect(ServerAddress.ValidationError.notHTTPS.message == "Use an https address")
        for error in [ServerAddress.ValidationError.empty, .invalid, .notHTTPS] {
            #expect(!error.message.contains("!"))
        }
    }
}
