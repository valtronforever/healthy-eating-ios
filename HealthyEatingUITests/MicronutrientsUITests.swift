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
        app.navigationBars.buttons.element(boundBy: 0).tap()

        // The weekly review, opened from Trends, has the same row.
        let review = app.buttons["weeklyReview"]
        XCTAssertTrue(app.scrollTo(review))
        review.tap()
        // Last week: early in a week this one may have no counted day yet.
        let previous = app.buttons["previousWeek"]
        XCTAssertTrue(previous.waitForExistence(timeout: 5))
        previous.tap()
        let weekLink = app.buttons["micronutrients"]
        XCTAssertTrue(app.scrollTo(weekLink))
        weekLink.tap()
        XCTAssertTrue(app.staticTexts["Iron"].waitForExistence(timeout: 5))
    }

    /// References are off until a group is chosen in Settings; then the day's list shows them.
    @MainActor
    func testReferencesAppearAfterChoosingAGroup() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-skipOnboarding", "-initialTab", "settings", "-AppleLocale", "en_US"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Alex Kim"].waitForExistence(timeout: 10))
        let picker = app.buttons["referenceGroup"]
        XCTAssertTrue(app.scrollTo(picker))
        picker.tap()
        // The menu can take a moment to open on a busy simulator.
        let women = app.buttons["Women 31–50"]
        XCTAssertTrue(women.waitForExistence(timeout: 10))
        women.tap()

        app.tabBars.buttons["Today"].tap()
        XCTAssertTrue(app.staticTexts["Chicken with rice and salad"].waitForExistence(timeout: 10))
        let link = app.buttons["micronutrients"]
        XCTAssertTrue(app.scrollTo(link))
        link.tap()
        XCTAssertTrue(app.navigationBars["Vitamins and minerals"].waitForExistence(timeout: 5))
        let iron = app.staticTexts["Reference 18–45 mg"]
        XCTAssertTrue(app.scrollTo(iron))
        keepScreenshot(named: "Vitamins and minerals with references")
    }

    /// A goal of the person's own replaces the reference for its nutrient; removing it brings the
    /// reference back.
    @MainActor
    func testSettingAndRemovingAGoal() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-skipOnboarding", "-initialTab", "settings", "-AppleLocale", "en_US"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Alex Kim"].waitForExistence(timeout: 10))
        let picker = app.buttons["referenceGroup"]
        XCTAssertTrue(app.scrollTo(picker))
        picker.tap()
        let women = app.buttons["Women 31–50"]
        XCTAssertTrue(women.waitForExistence(timeout: 10))
        women.tap()

        let goals = app.buttons["micronutrientGoals"]
        XCTAssertTrue(app.scrollTo(goals))
        goals.tap()
        XCTAssertTrue(app.navigationBars["Vitamin and mineral goals"].waitForExistence(timeout: 5))
        let iron = app.buttons["goal.iron_mg"]
        XCTAssertTrue(app.scrollTo(iron))
        XCTAssertTrue(iron.label.contains("Reference 18–45 mg"), iron.label)
        iron.tap()

        let from = app.textFields["From"]
        XCTAssertTrue(from.waitForExistence(timeout: 5))
        from.tap()
        from.typeText("10")
        let to = app.textFields["To"]
        to.tap()
        to.typeText("20")
        app.navigationBars["Iron"].buttons["Save"].tap()

        XCTAssertTrue(app.navigationBars["Vitamin and mineral goals"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.scrollTo(iron))
        XCTAssertTrue(iron.label.contains("Your goal 10–20 mg"), iron.label)
        keepScreenshot(named: "Vitamin and mineral goals")

        iron.tap()
        let remove = app.buttons["removeGoal"]
        XCTAssertTrue(remove.waitForExistence(timeout: 5))
        remove.tap()
        XCTAssertTrue(app.navigationBars["Vitamin and mineral goals"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.scrollTo(iron))
        XCTAssertTrue(iron.label.contains("Reference 18–45 mg"), iron.label)
    }

    @MainActor
    private func keepScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
