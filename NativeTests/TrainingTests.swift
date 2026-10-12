import XCTest
@testable import XiWang
final class TrainingTests:XCTestCase {
 func testMissingBackendConfigurationBlocksNavigation() { XCTAssertFalse(NavigationPolicy.trusted(URL(string:"https://example.com/"))) }
 func testUnsafeSchemesAndForeignOriginsBlocked() { for value in ["http://example.com/","https://example.com/","javascript:alert(1)","file:///etc/passwd","https://example.com:8443/"] { XCTAssertFalse(NavigationPolicy.trusted(URL(string:value))) } }
 func testNilURLBlocked() { XCTAssertFalse(NavigationPolicy.trusted(nil)) }
 func testEmbeddedCredentialsBlocked() { XCTAssertFalse(NavigationPolicy.trusted(URL(string:"https://user:pass@example.com/"))) }
}
