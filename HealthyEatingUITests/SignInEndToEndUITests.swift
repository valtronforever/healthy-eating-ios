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
        // A new account has no meals: A5 waits (polling the server) until skipped.
        XCTAssertTrue(app.staticTexts["Waiting for your first meal"].waitForExistence(timeout: 5))
        app.buttons["Skip for now"].tap()
        XCTAssertTrue(app.tabBars.buttons["Settings"].waitForExistence(timeout: 5))

        // Signing out revokes the session and returns to Welcome.
        app.tabBars.buttons["Settings"].tap()
        let signOut = app.buttons["Sign out"]
        app.scrollTo(signOut)
        signOut.tap()
        XCTAssertTrue(app.buttons["Get started"].waitForExistence(timeout: 10))
    }

    /// "MCP first": an assistant already saved a meal for this account (seed it with the
    /// assistant's MCP `log_meal` before the run; set TEST_RUNNER_HE_E2E_EMAIL and
    /// TEST_RUNNER_HE_E2E_MEAL). Signing in with the same account skips onboarding and Today
    /// shows the meal from the server.
    @MainActor
    func testAssistantFirstAccountOpensTodayWithItsMeals() throws {
        let environment = ProcessInfo.processInfo.environment
        guard let server = environment["HE_E2E_SERVER"], let email = environment["HE_E2E_EMAIL"],
              let meal = environment["HE_E2E_MEAL"]
        else {
            throw XCTSkip("Set TEST_RUNNER_HE_E2E_SERVER, _EMAIL and _MEAL to run this test")
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
        let allow = XCUIApplication(bundleIdentifier: "com.apple.springboard").buttons["Continue"]
        if allow.waitForExistence(timeout: 10) { allow.tap() }
        let emailField = app.webViews.textFields.firstMatch
        XCTAssertTrue(emailField.waitForExistence(timeout: 15))
        emailField.tap()
        emailField.typeText(email + "\n")

        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 15), "Onboarding is skipped")
        XCTAssertTrue(app.staticTexts[meal].waitForExistence(timeout: 10))
        keepScreenshot(named: "Today from the real server")

        app.tabBars.buttons["Settings"].tap()
        let signOut = app.buttons["Sign out"]
        app.scrollTo(signOut, maxSwipes: 8)
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
