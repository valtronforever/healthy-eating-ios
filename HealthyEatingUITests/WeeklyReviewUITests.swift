import XCTest

/// D2 Weekly review on the in-memory sample data (`-skipOnboarding`).
final class WeeklyReviewUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testOpenTheWeeklyReviewFromTrends() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-skipOnboarding", "-initialTab", "trends"]
        app.launch()

        XCTAssertTrue(app.navigationBars["Trends"].waitForExistence(timeout: 10))
        let entry = app.buttons["weeklyReview"]
        for _ in 0..<6 where !(entry.exists && entry.isHittable) { app.swipeUp() }
        entry.tap()

        XCTAssertTrue(app.navigationBars["Weekly review"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Days logged"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Protein per meal"].exists)
        // This week: there is no next week yet.
        XCTAssertFalse(app.buttons["nextWeek"].isEnabled)
        keepScreenshot(named: "D2 Weekly review this week")

        app.buttons["previousWeek"].tap()
        XCTAssertTrue(app.buttons["nextWeek"].waitForEnabled(timeout: 5))
        XCTAssertTrue(app.staticTexts["Days logged"].waitForExistence(timeout: 5))
        for _ in 0..<4 where !app.staticTexts["Low-confidence estimates"].isHittable { app.swipeUp() }
        XCTAssertTrue(app.staticTexts["Where values came from"].exists || app.otherElements["Where values came from"].exists)
        keepScreenshot(named: "D2 Weekly review last week")
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
    func waitForEnabled(timeout: TimeInterval) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isEnabled == true"), object: self)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }
}
