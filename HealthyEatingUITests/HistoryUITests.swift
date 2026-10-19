import XCTest

/// History on the in-memory sample data (`-skipOnboarding`).
final class HistoryUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testOpenADayAndMarkItPartial() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-skipOnboarding", "-initialTab", "history"]
        app.launch()

        let openDay = app.buttons["Open day"]
        XCTAssertTrue(openDay.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Complete"].exists || app.staticTexts["Partial"].exists || app.staticTexts["Not logged"].exists)
        keepScreenshot(named: "C1 History")
        openDay.tap()

        XCTAssertTrue(app.navigationBars.element.waitForExistence(timeout: 5))
        // The mark control is under the meals: scroll until the list shows it.
        let partial = app.segmentedControls.buttons["Partial"]
        for _ in 0..<6 where !partial.exists { app.swipeUp() }
        XCTAssertTrue(partial.waitForExistence(timeout: 5))
        partial.tap()
        XCTAssertTrue(partial.waitForSelection(timeout: 5))
        keepScreenshot(named: "Day view, marked partial")

        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["Open day"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Partial"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func keepScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

private extension XCUIElement {
    func waitForSelection(timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "isSelected == true")
        return XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: self)], timeout: timeout) == .completed
    }
}
