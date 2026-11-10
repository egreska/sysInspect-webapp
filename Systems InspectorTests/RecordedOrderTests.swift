import XCTest
@testable import Systems_Inspector

final class RecordedOrderTests: XCTestCase {
    func testLowerSequenceComesFirst() {
        let ordered = RecordedOrder.sorted(["Bay 2", "Bay 10", "Bay 1"]) { label in
            switch label {
            case "Bay 10": return 1
            case "Bay 2": return 2
            default: return 3
            }
        }
        XCTAssertEqual(ordered, ["Bay 10", "Bay 2", "Bay 1"])
    }

    func testEqualSequenceKeepsArrivalOrder() {
        let ordered = RecordedOrder.sorted(["first", "second", "third"]) { _ in 0 }
        XCTAssertEqual(ordered, ["first", "second", "third"])
    }
}
