import XCTest
@testable import TerraformKit

final class DeserializationTests: XCTestCase {
    
    let decoder = TerraformDecoder()
    
    func testPlan() {
        var plan : Plan! = nil
        XCTAssertNoThrow(plan = try decoder.decode(Plan.self, from: demo_plan))
        
        
        
        XCTAssert((plan.plannedValues.rootModule?.resources.count)! > 0)
    }
    
    func testEmptyPlan() {
        XCTAssertNoThrow(try decoder.decode(Plan.self, from: empty_plan))
    }
}
