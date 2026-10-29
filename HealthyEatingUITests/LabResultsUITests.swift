import XCTest

/// Lab results on the in-memory sample data (`-skipOnboarding`): three reports, vitamin D in
/// two units, and a CRP value the server does not know (ios#47).
final class LabResultsUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// From Trends: the list, an analyte with its chart and intake, a report, deleting one result
    /// and then the whole report.
    @MainActor
    func testLabResultsCanBeReadAndDeleted() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-skipOnboarding", "-initialTab", "trends", "-AppleLocale", "en_US"]
        app.launch()

        XCTAssertTrue(app.navigationBars["Trends"].waitForExistence(timeout: 10))
        let link = app.buttons["labResults"]
        XCTAssertTrue(app.scrollTo(link))
        link.tap()
        let vitaminD = app.buttons["labAnalyte.analyte.vitamin_d_25oh"]
        XCTAssertTrue(vitaminD.waitForExistence(timeout: 5))
        XCTAssertTrue(vitaminD.label.contains("18 ng/mL"), vitaminD.label)
        XCTAssertTrue(app.buttons["labAnalyte.name.crp"].label.contains("< 0.5 mg/dL"))
        keepScreenshot(named: "Lab results")

        // The analyte: latest value, the chart in nmol/L, and vitamin D intake below it.
        vitaminD.tap()
        XCTAssertTrue(app.navigationBars["25-OH vitamin D"].waitForExistence(timeout: 5))
        let latest = app.descendants(matching: .any)["labLatest"]
        XCTAssertTrue(latest.waitForExistence(timeout: 5))
        XCTAssertTrue(latest.label.contains("Lab range 30–100 ng/mL"), latest.label)
        XCTAssertTrue(app.staticTexts["Shown in nmol/L, converted from the units on your reports."].exists)
        let intake = app.staticTexts["Vitamin D intake from logged meals"]
        XCTAssertTrue(app.scrollTo(intake))
        keepScreenshot(named: "Lab analyte")

        // The newest value opens its report.
        let newest = app.buttons.matching(NSPredicate(format: "label CONTAINS '18 ng/mL'")).firstMatch
        XCTAssertTrue(app.scrollTo(newest))
        newest.tap()
        let crp = app.descendants(matching: .any)["labResult.CRP"]
        XCTAssertTrue(crp.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["6 results"].exists)
        keepScreenshot(named: "Lab report")

        // Delete one result with a swipe.
        crp.swipeLeft()
        app.buttons["Delete"].firstMatch.tap()
        XCTAssertTrue(waitForGone(crp))
        XCTAssertTrue(app.staticTexts["5 results"].waitForExistence(timeout: 5))

        // Delete the whole report, after a confirmation: the screen closes and vitamin D's
        // latest value is the older report's.
        let delete = app.buttons["deleteLabReport"]
        XCTAssertTrue(app.scrollTo(delete))
        delete.tap()
        XCTAssertTrue(app.sheets.buttons["Delete report"].waitForExistence(timeout: 5))
        app.sheets.buttons["Delete report"].tap()
        XCTAssertTrue(app.navigationBars["25-OH vitamin D"].waitForExistence(timeout: 5))
        XCTAssertTrue(waitForGone(newest))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let updated = app.buttons["labAnalyte.analyte.vitamin_d_25oh"]
        XCTAssertTrue(updated.waitForExistence(timeout: 5))
        XCTAssertTrue(updated.label.contains("52 nmol/L"), updated.label)
        XCTAssertFalse(app.buttons["labAnalyte.name.crp"].exists)
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
