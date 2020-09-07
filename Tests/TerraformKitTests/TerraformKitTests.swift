import XCTest
@testable import TerraformKit

final class TerraformKitTests: XCTestCase {
    var terraform: Terraform!
    
    override func setUp() {
        terraform = Terraform()
    }
    
    override func tearDown() {
        terraform.cleanup()
    }
    
    func testVersion() {
        XCTAssertEqual(try! terraform.version().version, Terraform.defaultTerraformVersion)
    }

    static var allTests = [
        ("testVersion", testVersion),
    ]
}
