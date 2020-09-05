import XCTest
@testable import TerraformKit

final class TerraformKitTests: XCTestCase {
    var terraform: Terraform!
    
    override func setUp() {
        terraform = Terraform()
    }
    
    override func tearDown() {
        try! terraform.destroy()
    }
    
    func testVersion() {
        XCTAssertEqual(try! terraform.version().version, Terraform.defaultTerraformVersion)
    }

    static var allTests = [
        ("testVersion", testVersion),
    ]
}
