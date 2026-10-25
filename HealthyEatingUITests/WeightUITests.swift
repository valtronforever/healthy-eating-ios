import XCTest

/// Weight on the in-memory sample data (`-skipOnboarding`, weight tracking on).
final class WeightUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// ios#41: add, correct and delete a weigh-in from Settings, in the person's unit.
    @MainActor
    func testWeighInsCanBeAddedCorrectedAndDeleted() throws {
        let app = XCUIApplication()
        // A fixed locale, so the decimal separator in the rows is known.
        app.launchArguments = ["-skipOnboarding", "-initialTab", "settings", "-AppleLocale", "en_US"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Alex Kim"].waitForExistence(timeout: 10))
        let unit = app.segmentedControls["weightUnit"]
        app.scrollTo(unit, maxSwipes: 4)
        XCTAssertTrue(unit.buttons["kg"].isSelected)

        let weighIns = app.buttons["weighIns"]
        app.scrollTo(weighIns, maxSwipes: 6)
        XCTAssertTrue(app.switches["weightTracking"].exists)
        keepScreenshot(named: "E1 Weight settings")
        weighIns.tap()
        XCTAssertTrue(app.navigationBars["Weigh-ins"].waitForExistence(timeout: 5))

        // Add 80,4 kg: either decimal separator works.
        app.navigationBars["Weigh-ins"].buttons["addWeighIn"].tap()
        let value = app.textFields["weightValue"]
        XCTAssertTrue(value.waitForExistence(timeout: 5))
        value.tap()
        value.typeText("80,4")
        keepScreenshot(named: "Add weigh-in")
        app.navigationBars["Add weigh-in"].buttons["Save"].tap()
        let added = row("80.4 kg", in: app)
        XCTAssertTrue(added.waitForExistence(timeout: 5))

        // Correct it.
        added.tap()
        XCTAssertTrue(value.waitForExistence(timeout: 5))
        XCTAssertEqual(value.value as? String, "80.4")
        // Tap the end of the field, so the deletes clear the whole value.
        value.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        value.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 6) + "80.2")
        app.navigationBars["Edit weigh-in"].buttons["Save"].tap()
        let corrected = row("80.2 kg", in: app)
        XCTAssertTrue(corrected.waitForExistence(timeout: 5))

        // Delete it from the form, after a confirmation.
        corrected.tap()
        app.buttons["Delete weigh-in"].firstMatch.tap()
        XCTAssertTrue(app.sheets.buttons["Delete weigh-in"].waitForExistence(timeout: 5))
        app.sheets.buttons["Delete weigh-in"].tap()
        XCTAssertTrue(waitForGone(corrected))
    }

    /// ios#33: D3 from Trends, with the trend, the energy estimate, and the off state.
    @MainActor
    func testWeightAndEnergyCanBeTurnedOffAndOn() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-skipOnboarding", "-initialTab", "trends", "-AppleLocale", "en_US"]
        app.launch()

        let link = app.buttons["weightAndEnergy"]
        app.scrollTo(link, maxSwipes: 6)
        link.tap()
        XCTAssertTrue(app.staticTexts["kg trend"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["−0.3 kg per week over the last 4 weeks"].exists)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Based on your log and weight")).firstMatch.exists)
        keepScreenshot(named: "D3 Weight and energy on")

        app.buttons["How this is calculated"].tap()
        XCTAssertTrue(app.navigationBars["How this is calculated"].waitForExistence(timeout: 5))
        app.navigationBars["How this is calculated"].buttons["Done"].tap()
        XCTAssertTrue(waitForGone(app.navigationBars["How this is calculated"]))

        // "Show on Trends" off hides weight: the screen turns into the intro. Scroll to the end,
        // so the switch is clear of the floating tab bar.
        let show = app.switches["Show on Trends"]
        let deleteAll = app.buttons["Delete all weight data"]
        app.scrollTo(deleteAll, maxSwipes: 4)
        app.swipeUp()
        XCTAssertTrue(show.isHittable)
        show.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        let turnOn = app.buttons["turnOnWeight"]
        XCTAssertTrue(turnOn.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Optional: weight and energy"].exists)
        keepScreenshot(named: "D3 Weight and energy off")

        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.staticTexts["Off"].waitForExistence(timeout: 5))
        link.tap()
        XCTAssertTrue(turnOn.waitForExistence(timeout: 5))
        turnOn.tap()
        XCTAssertTrue(app.staticTexts["kg trend"].waitForExistence(timeout: 5))
    }

    /// ios#32: Apple Health sync on D3 (placeholder store: three weigh-ins, no HealthKit).
    @MainActor
    func testAppleHealthSyncIsOptIn() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-resetOnboarding", "-skipOnboarding", "-initialTab", "trends", "-AppleLocale", "en_US"]
        app.launch()

        let link = app.buttons["weightAndEnergy"]
        app.scrollTo(link, maxSwipes: 6)
        link.tap()
        XCTAssertTrue(app.staticTexts["kg trend"].waitForExistence(timeout: 10))
        let toggle = app.switches["appleHealthSync"]
        let deleteAll = app.buttons["Delete all weight data"]
        app.scrollTo(deleteAll, maxSwipes: 4)
        app.swipeUp()
        XCTAssertEqual(toggle.value as? String, "0", "off by default")
        XCTAssertTrue(app.staticTexts["Meals and body weight, when the app opens"].exists)

        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        let imported = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "changes synced")).firstMatch
        XCTAssertTrue(imported.waitForExistence(timeout: 5))
        XCTAssertEqual(toggle.value as? String, "1")
        keepScreenshot(named: "D3 Apple Health sync on")
    }

    /// A weigh-in row is one button whose label holds the date, source and value.
    @MainActor
    private func row(_ value: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", value)).firstMatch
    }

    @MainActor
    private func waitForGone(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    @MainActor
    private func keepScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
