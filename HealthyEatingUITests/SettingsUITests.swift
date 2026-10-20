import XCTest

/// Settings on the in-memory sample data (`-skipOnboarding`).
final class SettingsUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testSettingsConnectionsTargetsAndDeleteAccount() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-skipOnboarding", "-initialTab", "settings"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Alex Kim"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Signed in with Google and Apple"].exists)
        keepScreenshot(named: "E1 Settings")

        // Energy unit
        app.segmentedControls.buttons["kJ"].tap()
        XCTAssertTrue(app.segmentedControls.buttons["kJ"].isSelected)

        // E2 connected assistants: revoke ChatGPT
        app.buttons["connectedAssistants"].tap()
        XCTAssertTrue(app.staticTexts["ChatGPT"].waitForExistence(timeout: 5))
        let revokeButtons = app.buttons.matching(identifier: "Revoke")
        XCTAssertEqual(revokeButtons.count, 2, "Claude and ChatGPT; this iPhone has no Revoke")
        revokeButtons.element(boundBy: 1).tap()
        XCTAssertTrue(app.alerts["Revoke ChatGPT?"].waitForExistence(timeout: 5))
        keepScreenshot(named: "E2 Revoke confirmation")
        app.alerts.buttons["Revoke"].tap()
        XCTAssertFalse(app.staticTexts["ChatGPT"].waitForExistence(timeout: 3))
        app.navigationBars.buttons.element(boundBy: 0).tap()

        // Target ranges: open the protein upper bound
        app.buttons["targetRanges"].tap()
        let save = app.navigationBars["Target ranges"].buttons["Save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        XCTAssertFalse(save.isEnabled)
        app.navigationBars.buttons.element(boundBy: 0).tap()

        // E3 delete account
        let delete = app.buttons["Delete account"]
        while !delete.isHittable { app.swipeUp() }
        delete.tap()
        let confirmField = app.textFields["deleteConfirmation"]
        XCTAssertTrue(confirmField.waitForExistence(timeout: 5))
        let confirm = app.buttons["confirmDeleteAccount"]
        XCTAssertFalse(confirm.isEnabled)
        confirmField.tap()
        confirmField.typeText("DELETE")
        keepScreenshot(named: "E3 Delete account")
        confirm.tap()
        XCTAssertTrue(app.buttons["Get started"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testNoticeWhenMealsStopArrivingIsOptIn() throws {
        let app = XCUIApplication()
        // -resetOnboarding first: the notice is stored per device and must start off.
        app.launchArguments = ["-resetOnboarding", "-skipOnboarding", "-initialTab", "settings"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Alex Kim"].waitForExistence(timeout: 10))
        // The list renders rows as they scroll into view.
        let notice = app.switches["arrivalNotice"]
        for _ in 0..<6 where !(notice.exists && notice.isHittable) { app.swipeUp() }
        XCTAssertTrue(notice.isHittable)
        XCTAssertEqual(notice.value as? String, "0", "off by default")
        XCTAssertTrue(app.staticTexts["One quiet notification after 2 days"].exists)

        // Placeholder runs grant notifications without the system prompt.
        // The switch itself sits at the trailing edge of the row.
        let knob = notice.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5))
        knob.tap()
        XCTAssertTrue(waitForValue("1", of: notice))
        keepScreenshot(named: "E1 Notice when meals stop arriving on")
        knob.tap()
        XCTAssertTrue(waitForValue("0", of: notice))
    }

    @MainActor
    private func waitForValue(_ value: String, of element: XCUIElement) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", value), object: element)
        return XCTWaiter.wait(for: [expectation], timeout: 5) == .completed
    }

    @MainActor
    private func keepScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
