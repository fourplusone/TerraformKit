import XCTest
@testable import TerraformKit

final class DeserializationTests: XCTestCase {
    
    let decoder = TerraformDecoder()
    
    func testPlan() {
        var plan : Plan! = nil
        XCTAssertNoThrow(plan = try decoder.decode(Plan.self, from: demoPlan))
        XCTAssert((plan.plannedValues.rootModule?.resources.count)! > 0)
    }
    
    func testOutputPlan() {
        var plan : Plan! = nil
        XCTAssertNoThrow(plan = try decoder.decode(Plan.self, from: outputPlan))
        XCTAssert(plan.outputChanges.count > 0)
    }
    
    func testVariablesPlan() {
        var plan : Plan! = nil
        XCTAssertNoThrow(plan = try decoder.decode(Plan.self, from: variablesPlan))
        XCTAssert(plan.variables.count > 0)
    }
    
    func testEmptyPlan() {
        XCTAssertNoThrow(try decoder.decode(Plan.self, from: emptyPlan))
    }
}
