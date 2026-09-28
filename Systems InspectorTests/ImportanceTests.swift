//
//  ImportanceTests.swift
//  Systems InspectorTests
//

import XCTest
@testable import Systems_Inspector

final class ImportanceTests: XCTestCase {

    func testStoredNeedsImmediateAttentionAndCriticalAreImmediate() {
        XCTAssertEqual(Importance(stored: "Needs immediate attention"), .needsImmediateAttention)
        XCTAssertEqual(Importance(stored: "Critical"), .needsImmediateAttention)
        XCTAssertTrue(Importance.needsImmediateAttention.isImmediate)
        XCTAssertEqual(Importance.needsImmediateAttention.phrase, "Needs immediate attention")
    }

    func testMissingRepairUrgentAndOtherWordsAreMonitor() {
        XCTAssertEqual(Importance(stored: nil), .monitor)
        XCTAssertEqual(Importance(stored: ""), .monitor)
        XCTAssertEqual(Importance(stored: "Repair"), .monitor)
        XCTAssertEqual(Importance(stored: "Urgent"), .monitor)
        XCTAssertEqual(Importance(stored: "critical"), .monitor)
        XCTAssertEqual(Importance(stored: "   "), .monitor)
        XCTAssertFalse(Importance.monitor.isImmediate)
        XCTAssertEqual(Importance.monitor.phrase, "Monitor")
    }

    func testToggleFlipsTheTwoValues() {
        XCTAssertEqual(Importance.monitor.toggled, .needsImmediateAttention)
        XCTAssertEqual(Importance.needsImmediateAttention.toggled, .monitor)
    }

    func testImmediateSortsBeforeMonitor() {
        let ordered = [Importance.monitor, Importance.needsImmediateAttention, Importance.monitor].sorted()
        XCTAssertEqual(ordered, [.needsImmediateAttention, .monitor, .monitor])
    }

    func testCountsEachValue() {
        let counts = Importance.counts(in: [.needsImmediateAttention, .monitor, .needsImmediateAttention])
        XCTAssertEqual(counts.immediate, 2)
        XCTAssertEqual(counts.monitor, 1)
    }
}
