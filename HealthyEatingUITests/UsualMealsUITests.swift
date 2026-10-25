import XCTest

/// ios#39: log a usual meal again from Today (sample data, `-skipOnboarding`).
final class UsualMealsUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testUsualMealIsLoggedAgainFromToday() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-skipOnboarding", "-initialTab", "today"]
        app.launch()

        let entry = app.buttons["logUsualMeal"]
        app.scrollTo(entry, maxSwipes: 6)
        let yogurt = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Greek yogurt with honey"))
        let before = yogurt.count
        entry.tap()

        XCTAssertTrue(app.navigationBars["Usual meals"].waitForExistence(timeout: 5))
        keepScreenshot(named: "Usual meals")
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Greek yogurt with honey")).firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Log again"].waitForExistence(timeout: 5))
        keepScreenshot(named: "Log again")
        app.buttons["logMeal"].tap()

        XCTAssertTrue(app.buttons["logUsualMeal"].waitForExistence(timeout: 5))
        XCTAssertTrue(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "count > %d", before), object: yogurt)], timeout: 5) == .completed)
    }

    @MainActor
    private func keepScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
