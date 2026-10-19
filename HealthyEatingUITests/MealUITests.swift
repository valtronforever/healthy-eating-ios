import XCTest

/// Meal detail, edit and delete on the in-memory sample data (`-skipOnboarding`).
final class MealUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testEditAMealThenDeleteIt() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-skipOnboarding", "-initialTab", "today"]
        app.launch()

        let meal = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "Chicken with rice and salad")).firstMatch
        XCTAssertTrue(meal.waitForExistence(timeout: 10))
        meal.tap()
        XCTAssertTrue(app.staticTexts["Chicken with rice and salad"].waitForExistence(timeout: 5))

        app.navigationBars.buttons["Edit"].tap()
        let calories = app.textFields["calories_kcal"]
        XCTAssertTrue(calories.waitForExistence(timeout: 5))
        XCTAssertFalse(app.navigationBars["Edit meal"].buttons["Save"].isEnabled, "Nothing changed yet")
        calories.tap()
        calories.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        let typed = calories.value as? String ?? ""
        calories.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: typed.count) + "650")
        keepScreenshot(named: "B4 Edit meal")
        app.navigationBars["Edit meal"].buttons["Save"].tap()

        XCTAssertTrue(app.staticTexts["650 kcal"].waitForExistence(timeout: 5))

        let delete = app.buttons["Delete meal"]
        while !delete.isHittable { app.swipeUp() }
        delete.tap()
        let confirm = app.sheets.buttons["Delete meal"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        keepScreenshot(named: "B3 Delete confirmation")
        confirm.tap()

        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Chicken with rice and salad"].waitForExistence(timeout: 3))
    }

    @MainActor
    private func keepScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
