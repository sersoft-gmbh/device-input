#if swift(<5.4)
import XCTest

import DeviceInputTests

var tests = [XCTestCaseEntry]()
tests += DeviceInputTests.__allTests()

XCTMain(tests)
#endif
