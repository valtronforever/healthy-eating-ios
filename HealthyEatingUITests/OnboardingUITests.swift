import XCTest

final class OnboardingUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testOnboardingRejectsHTTPThenConnects() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-resetOnboarding", "-placeholderSignIn"]
        app.launch()

        app.buttons["Get started"].tap()

        let field = app.textFields["serverAddress"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Continue"].isEnabled, "Continue stays disabled until something is typed")
        field.tap()
        field.typeText("http://food.example.com")
        app.buttons["Continue"].tap()
        XCTAssertTrue(app.staticTexts["Use an https address"].waitForExistence(timeout: 2))
        keepScreenshot(named: "A2 Server, https error")

        // Put the cursor after the last character before deleting what was typed.
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.5)).tap()
        let typed = field.value as? String ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: typed.count))
        field.typeText("https://food.example.com")
        app.buttons["Continue"].tap()

        XCTAssertTrue(app.staticTexts["Connect your AI assistant"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["https://food.example.com/mcp"].waitForExistence(timeout: 2))
        app.buttons["ChatGPT"].tap()
        XCTAssertTrue(app.staticTexts["In a web browser, open chatgpt.com and go to Plugins."].exists)
        keepScreenshot(named: "A4 Connect your AI assistant")

        app.buttons["I’ve connected it"].tap()
        XCTAssertTrue(app.staticTexts["Waiting for your first meal"].waitForExistence(timeout: 5))
        keepScreenshot(named: "A5 Waiting for your first meal")
        // The sample account's first meal arrives on the next status check.
        XCTAssertTrue(app.staticTexts["First meal received from ChatGPT"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Oatmeal with berries"].exists)
        keepScreenshot(named: "A5 First meal received")
        app.buttons["Go to Today"].tap()
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Oatmeal with berries"].waitForExistence(timeout: 5))
    }

    /// Screenshots for comparing the screens with the design boards (kept in the result bundle).
    @MainActor
    private func keepScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testTabsShowTheirScreens() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-skipOnboarding"]
        app.launch()

        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Chicken with rice and salad"].exists)
        for tab in ["History", "Trends", "Settings"] {
            app.tabBars.buttons[tab].tap()
            XCTAssertTrue(app.navigationBars[tab].waitForExistence(timeout: 5), "\(tab) screen")
        }
    }
}
