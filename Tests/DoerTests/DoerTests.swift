import XCTest
@testable import Doer

final class DoerTests: XCTestCase {
  // TODO: Needs more tests
  func testEcho() {
    let hello0 = "Hello World"
    let hello1 = Doer.task("/bin/echo", hello0).output?.trimmingCharacters(in: .whitespacesAndNewlines)
    XCTAssertEqual(hello0, hello1)
  }
  
  static var allTests = [
    ("testEcho", testEcho)
  ]
}




