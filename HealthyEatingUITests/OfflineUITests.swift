import XCTest

/// G1 offline with cached data (ios#20), with `-showOffline` on the sample data.
final class OfflineUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testOfflineBannerOnTodayHistoryAndTrends() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-skipOnboarding", "-showOffline", "-AppleLocale", "en_US"]
        app.launch()

        let banner = app.staticTexts["Offline"]
        XCTAssertTrue(banner.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Showing data from")).firstMatch.exists)
        keepScreenshot(named: "G1 Offline with cached data")

        app.tabBars.buttons["History"].tap()
        XCTAssertTrue(app.staticTexts["Offline"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Trends"].tap()
        XCTAssertTrue(app.staticTexts["Offline"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func keepScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
