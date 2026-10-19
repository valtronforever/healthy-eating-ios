import XCTest

/// Signs in to a real, locally running backend through the system web sheet and its development
/// login. Skipped unless a server is given, so CI and normal runs never need a backend:
///
///   TEST_RUNNER_HE_E2E_SERVER=http://localhost:8000 xcodebuild test \
///     -only-testing:HealthyEatingUITests/SignInEndToEndUITests ...
///
/// The backend must run with DEV_LOGIN_ENABLED=true (see the backend README).
final class SignInEndToEndUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testSignInThroughTheServersLoginPage() throws {
        guard let server = ProcessInfo.processInfo.environment["HE_E2E_SERVER"] else {
            throw XCTSkip("Set TEST_RUNNER_HE_E2E_SERVER to a backend with dev login to run this test")
        }
        let app = XCUIApplication()
        app.launchArguments = ["-resetOnboarding"]
        app.launch()

        app.buttons["Get started"].tap()
        let field = app.textFields["serverAddress"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(server)
        app.buttons["Continue"].tap()

        // iOS asks before an app opens a web sign-in.
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons["Continue"]
        if allow.waitForExistence(timeout: 10) {
            allow.tap()
        }

        let email = app.webViews.textFields.firstMatch
        XCTAssertTrue(email.waitForExistence(timeout: 15), "The server's login page did not open")
        keepScreenshot(named: "A3 Sign in, server login page")
        email.tap()
        // Return submits the form; the button itself is under the keyboard.
        email.typeText("e2e-\(UUID().uuidString.prefix(8))@example.com\n")

        XCTAssertTrue(app.staticTexts["Connect your AI assistant"].waitForExistence(timeout: 15))
        keepScreenshot(named: "A4 after a real sign-in")
        app.buttons["I’ve connected it"].tap()
        XCTAssertTrue(app.tabBars.buttons["Settings"].waitForExistence(timeout: 5))

        // Signing out revokes the session and returns to Welcome.
        app.tabBars.buttons["Settings"].tap()
        let signOut = app.buttons["Sign out"]
        while !signOut.isHittable { app.swipeUp() }
        signOut.tap()
        XCTAssertTrue(app.buttons["Get started"].waitForExistence(timeout: 10))
    }

    @MainActor
    private func keepScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
