import XCTest

/// G3 Calm mode on the sample data (`-skipOnboarding`): no calories anywhere, a plain consistency line.
final class CalmModeUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testCalmModeHidesCalories() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-resetOnboarding", "-skipOnboarding", "-initialTab", "settings"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Alex Kim"].waitForExistence(timeout: 10))
        let calm = app.switches.matching(NSPredicate(format: "label BEGINSWITH 'Calm mode'")).firstMatch
        app.scrollTo(calm, maxSwipes: 8)
        calm.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        XCTAssertTrue(wait(for: calm, value: "1"))

        app.tabBars.buttons["Today"].tap()
        let consistency = app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH 'Logged '")).firstMatch
        XCTAssertTrue(consistency.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["kcal so far"].exists)
        XCTAssertFalse(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'kcal'")).firstMatch.exists)
        keepScreenshot(named: "G3 Today in Calm mode")

        app.staticTexts["Chicken with rice and salad"].tap()
        XCTAssertTrue(app.staticTexts["Protein"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Calories"].exists)
    }

    @MainActor
    private func wait(for element: XCUIElement, value: String) -> Bool {
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
