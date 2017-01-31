import XCTest
@testable import DeviceInput

class DeviceInputTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        XCTAssertEqual(DeviceInput().text, "Hello, World!")
    }


    static var allTests : [(String, (DeviceInputTests) -> () throws -> Void)] {
        return [
            ("testExample", testExample),
        ]
    }
}
