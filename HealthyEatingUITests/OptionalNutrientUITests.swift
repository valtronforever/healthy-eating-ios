import XCTest

/// Fiber, sugar and sodium on the sample data (`-skipOnboarding`).
final class OptionalNutrientUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testTodayAndMealDetailShowThem() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-skipOnboarding"]
        app.launch()

        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 10))
        let line = app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH 'Fiber '")).firstMatch
        XCTAssertTrue(line.waitForExistence(timeout: 5))
        keepScreenshot(named: "B1 Today with fiber, sugar and sodium")

        app.staticTexts["Chicken with rice and salad"].tap()
        XCTAssertTrue(app.staticTexts["Sodium"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Fiber"].exists)
        keepScreenshot(named: "B3 Meal detail with fiber, sugar and sodium")

        app.tabBars.buttons["Trends"].tap()
        XCTAssertTrue(app.navigationBars["Trends"].waitForExistence(timeout: 5))
        let sodium = app.staticTexts["Sodium"]
        for _ in 0..<4 where !(sodium.exists && sodium.isHittable) { app.swipeUp() }
        XCTAssertTrue(sodium.exists)
        keepScreenshot(named: "D1 Trends with fiber, sugar and sodium")
    }

    @MainActor
    private func keepScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
