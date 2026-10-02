import XCTest
final class NavigationTests:XCTestCase {
 var app:XCUIApplication!
 override func setUpWithError() throws { continueAfterFailure=false;app=XCUIApplication();app.launch() }
 func testOriginalInterfaceAndNavigation() {
  let web=app.webViews.firstMatch;XCTAssertTrue(web.waitForExistence(timeout:10))
  if web.buttons["确定访问"].waitForExistence(timeout:8) { web.buttons["确定访问"].tap() }
  XCTAssertTrue(web.buttons["今天"].waitForExistence(timeout:60))
  let home=XCTAttachment(screenshot:app.screenshot());home.name="KneeHope-Original-Today";home.lifetime = .keepAlways;add(home)
  web.buttons["记录"].tap();XCTAssertTrue(web.buttons["计划"].waitForExistence(timeout:10));web.buttons["计划"].tap();XCTAssertTrue(web.buttons["今天"].exists);web.buttons["今天"].tap()
  web.swipeUp();web.swipeDown();XCTAssertTrue(web.buttons["问问膝望"].exists)
 }
 func testDesktopEnglishNameAndSystemIconMask() {
  XCUIDevice.shared.press(.home);let desktop=XCUIApplication(bundleIdentifier:"com.apple.springboard");XCTAssertTrue(desktop.icons["KneeHope"].waitForExistence(timeout:5));let icon=XCTAttachment(screenshot:desktop.screenshot());icon.name="KneeHope-Desktop-Icon";icon.lifetime = .keepAlways;add(icon)
 }
}
