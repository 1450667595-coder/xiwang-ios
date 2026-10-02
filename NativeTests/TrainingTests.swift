import XCTest
@testable import XiWang
final class TrainingTests:XCTestCase {
 func testSameOriginHTTPSNavigation() { XCTAssertTrue(NavigationPolicy.trusted(NavigationPolicy.home)); XCTAssertTrue(NavigationPolicy.trusted(NavigationPolicy.home.appendingPathComponent("api/records"))) }
 func testUnsafeSchemesAndForeignOriginsBlocked() { for value in ["http://xw-1001-d7g1pemw9f07da790-1253484462.ap-shanghai.app.tcloudbase.com/","https://example.com/","javascript:alert(1)","file:///etc/passwd","https://xw-1001-d7g1pemw9f07da790-1253484462.ap-shanghai.app.tcloudbase.com:8443/"] { XCTAssertFalse(NavigationPolicy.trusted(URL(string:value))) } }
 func testNilURLBlocked() { XCTAssertFalse(NavigationPolicy.trusted(nil)) }
 func testEmbeddedCredentialsBlocked() { XCTAssertFalse(NavigationPolicy.trusted(URL(string:"https://user:pass@xw-1001-d7g1pemw9f07da790-1253484462.ap-shanghai.app.tcloudbase.com/"))) }
}
