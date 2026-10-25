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

        // Scroll the row into place first: a tap during XCUITest's own scroll-to-visible can land
        // while the list still moves and only stop it (CI run 40190320139).
        let meal = app.staticTexts["Chicken with rice and salad"]
        app.scrollTo(meal)
        meal.tap()
        XCTAssertTrue(app.staticTexts["Sodium"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Fiber"].exists)
        keepScreenshot(named: "B3 Meal detail with fiber, sugar and sodium")

        app.tabBars.buttons["Trends"].tap()
        XCTAssertTrue(app.navigationBars["Trends"].waitForExistence(timeout: 5))
        let sodium = app.staticTexts["Sodium"]
        app.scrollTo(sodium, maxSwipes: 4)
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
