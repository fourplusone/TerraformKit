import XCTest

import TerraformKitTests

var tests = [XCTestCaseEntry]()
tests += TerraformKitTests.allTests()
tests += DeserializationTests.allTests()

XCTMain(tests)
