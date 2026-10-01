import XCTest
final class NavigationTests:XCTestCase {
    var app:XCUIApplication!
    override func setUpWithError() throws { continueAfterFailure = false; app = XCUIApplication(); app.launchArguments = ["--ui-testing"]; app.launch() }
    func testNativeTabsAndProjectSkip() {
        let home = XCTAttachment(screenshot:app.screenshot()); home.name = "KneeHope-Today"; home.lifetime = .keepAlways; add(home)
        app.tabBars.buttons["训练"].tap(); app.buttons["begin-session"].tap()
        XCTAssertTrue(app.staticTexts["直腿抬高"].firstMatch.waitForExistence(timeout:5))
        app.buttons["skip-exercise"].tap(); app.buttons["直接跳过"].tap()
        XCTAssertTrue(app.staticTexts["靠墙静蹲"].firstMatch.waitForExistence(timeout:5))
        let training = XCTAttachment(screenshot:app.screenshot()); training.name = "KneeHope-Training"; training.lifetime = .keepAlways; add(training)
        app.tabBars.buttons["设置"].tap(); XCTAssertTrue(app.staticTexts["跨设备同步"].exists)
        let settings = XCTAttachment(screenshot:app.screenshot()); settings.name = "KneeHope-Settings"; settings.lifetime = .keepAlways; add(settings)
    }
    func testCareRecordAndNavigationBack() {
        app.tabBars.buttons["护理"].tap(); app.buttons["add-care"].tap(); app.buttons["save-care"].tap()
        XCTAssertTrue(app.staticTexts["热敷"].firstMatch.waitForExistence(timeout:5))
        app.tabBars.buttons["记录"].tap(); XCTAssertTrue(app.staticTexts["还没有记录"].exists)
    }
    func testHomeScrollResponsiveness() { measure(metrics:[XCTOSSignpostMetric.scrollDecelerationMetric]) { app.scrollViews.firstMatch.swipeUp(); app.scrollViews.firstMatch.swipeDown() } }
}
