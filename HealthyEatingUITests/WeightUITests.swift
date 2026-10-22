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
        for _ in 0..<4 where !(unit.exists && unit.isHittable) { app.swipeUp() }
        XCTAssertTrue(unit.buttons["kg"].isSelected)

        let weighIns = app.buttons["weighIns"]
        for _ in 0..<6 where !(weighIns.exists && weighIns.isHittable) { app.swipeUp() }
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
