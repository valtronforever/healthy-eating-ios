import XCTest

/// Vitamins and minerals on the sample data (`-skipOnboarding`): Today's link, the meal's
/// items and Trends' averages (backend #25).
final class MicronutrientsUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testTodayMealDetailAndTrendsShowVitaminsAndMinerals() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-skipOnboarding", "-initialTab", "today", "-AppleLocale", "en_US"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Chicken with rice and salad"].waitForExistence(timeout: 10))
        let link = app.buttons["micronutrients"]
        XCTAssertTrue(app.scrollTo(link))
        link.tap()
        XCTAssertTrue(app.navigationBars["Vitamins and minerals"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Iron"].exists)
        XCTAssertTrue(app.staticTexts["2 of 3 meals"].exists)
        keepScreenshot(named: "Today vitamins and minerals")
        app.navigationBars.buttons.element(boundBy: 0).tap()

        let meal = app.staticTexts["Chicken with rice and salad"]
        app.scrollTo(meal)
        meal.tap()
        let item = app.staticTexts["USDA: Rice, white, cooked, NS as to fat"]
        XCTAssertTrue(app.staticTexts["Chicken with rice and salad"].waitForExistence(timeout: 5))
        app.scrollTo(item)
        XCTAssertTrue(item.exists)
        XCTAssertTrue(app.staticTexts["Not found in USDA data, no values"].exists)
        keepScreenshot(named: "Meal detail food items")
        app.navigationBars.buttons.element(boundBy: 0).tap()

        app.tabBars.buttons["Trends"].tap()
        XCTAssertTrue(app.navigationBars["Trends"].waitForExistence(timeout: 10))
        let trendsLink = app.buttons["micronutrients"]
        XCTAssertTrue(app.scrollTo(trendsLink))
        trendsLink.tap()
        XCTAssertTrue(app.staticTexts["Vitamin B12"].waitForExistence(timeout: 5))
        keepScreenshot(named: "Trends vitamins and minerals")
    }

    @MainActor
    private func keepScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
