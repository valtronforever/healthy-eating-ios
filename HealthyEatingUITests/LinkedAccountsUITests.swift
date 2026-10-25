import XCTest

/// Linked accounts (#20) on the in-memory sample data: the placeholder web sheet "signs in" with
/// Microsoft at once.
final class LinkedAccountsUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testLinkAndUnlinkAnAccount() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-skipOnboarding", "-initialTab", "settings", "-AppleLocale", "en_US"]
        app.launch()

        let linked = app.buttons["linkedAccounts"]
        XCTAssertTrue(linked.waitForExistence(timeout: 10))
        linked.tap()
        XCTAssertTrue(app.staticTexts["Google"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Apple"].exists)
        XCTAssertEqual(app.buttons.matching(identifier: "unlinkAccount").count, 2)

        app.buttons["linkAccount"].tap()
        XCTAssertTrue(app.staticTexts["Microsoft account linked. You can sign in with it from now on."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Microsoft"].exists)
        keepScreenshot(named: "Linked accounts after linking Microsoft")

        app.buttons.matching(identifier: "unlinkAccount").element(boundBy: 0).tap()
        XCTAssertTrue(app.alerts["Unlink the Google account?"].waitForExistence(timeout: 5))
        keepScreenshot(named: "Unlink confirmation")
        app.alerts.buttons["Unlink"].tap()
        XCTAssertTrue(waitForValue("0", of: app.staticTexts["Google"], key: "exists", timeout: 10))

        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.staticTexts["Signed in with Apple and Microsoft"].waitForExistence(timeout: 5))
    }

    private func waitForValue(_ value: String, of element: XCUIElement, key: String = "value", timeout: TimeInterval = 5) -> Bool {
        let predicate = key == "exists"
            ? NSPredicate(format: "exists == %@", NSNumber(value: value == "1"))
            : NSPredicate(format: "value == %@", value)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    @MainActor
    private func keepScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
