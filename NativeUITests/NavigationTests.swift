import XCTest
final class NavigationTests:XCTestCase {
 var app:XCUIApplication!
 override func setUpWithError() throws { continueAfterFailure=false;app=XCUIApplication();app.launch() }
 override func tearDownWithError() throws { app.terminate() }
 func testOriginalInterfaceAndNavigation() {
  let web=app.webViews.firstMatch;XCTAssertTrue(web.waitForExistence(timeout:10))
  XCTAssertEqual(web.frame.minY,0,accuracy:1);XCTAssertEqual(web.frame.maxY,app.windows.firstMatch.frame.maxY,accuracy:1)
  let deadline=Date().addingTimeInterval(60)
  while !web.buttons["开始训练"].exists && Date() < deadline {
   let visit=web.buttons["确定访问"];if visit.exists && visit.isEnabled { visit.tap() };Thread.sleep(forTimeInterval:1)
  }
  let ready=web.buttons["开始训练"].exists
  let diagnostic=XCTAttachment(screenshot:app.screenshot());diagnostic.name="Original-Load-Diagnostic";diagnostic.lifetime = .keepAlways;add(diagnostic)
  if !ready { print(app.debugDescription) };XCTAssertTrue(ready)
  let home=XCTAttachment(screenshot:app.screenshot());home.name="KneeHope-Original-Today";home.lifetime = .keepAlways;add(home)
  let tabs=app.tabBars.firstMatch;XCTAssertTrue(tabs.waitForExistence(timeout:10))
  tabs.buttons["记录"].tap();XCTAssertTrue(tabs.buttons["记录"].isSelected);tabs.buttons["计划"].tap();XCTAssertTrue(web.staticTexts["我的计划"].waitForExistence(timeout:10))
  let plan=XCTAttachment(screenshot:app.screenshot());plan.name="KneeHope-Full-Cover-Native-Tabs";plan.lifetime = .keepAlways;add(plan)
  tabs.buttons["今天"].tap();XCTAssertTrue(web.buttons["开始训练"].waitForExistence(timeout:10))
  web.swipeUp();web.swipeDown();XCTAssertTrue(web.buttons["问问膝望"].exists)
 }
 func testDesktopEnglishNameAndSystemIconMask() {
  XCUIDevice.shared.press(.home);let desktop=XCUIApplication(bundleIdentifier:"com.apple.springboard");XCTAssertTrue(desktop.icons["KneeHope"].waitForExistence(timeout:5));let icon=XCTAttachment(screenshot:desktop.screenshot());icon.name="KneeHope-Desktop-Icon";icon.lifetime = .keepAlways;add(icon)
 }
}




