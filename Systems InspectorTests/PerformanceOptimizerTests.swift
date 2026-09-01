//
//  PerformanceOptimizerTests.swift
//  Systems InspectorTests
//

import XCTest
@testable import Systems_Inspector

final class PerformanceOptimizerTests: XCTestCase {

    var sut: PerformanceOptimizer!

    override func setUp() {
        super.setUp()
        sut = PerformanceOptimizer.shared
        sut.resetMetrics()
    }

    override func tearDown() {
        sut.resetMetrics()
        sut = nil
        super.tearDown()
    }

    func testGetCellHeightCalculatesFirstTime() {
        let identifier = "test_cell_1"
        var calculateCount = 0

        let height = sut.getCellHeight(for: identifier) {
            calculateCount += 1
            return 100.0
        }

        XCTAssertEqual(height, 100.0)
        XCTAssertEqual(calculateCount, 1)
    }

    func testGetCellHeightReturnsCachedValue() {
        let identifier = "test_cell_2"
        var calculateCount = 0

        _ = sut.getCellHeight(for: identifier) {
            calculateCount += 1
            return 100.0
        }

        let height = sut.getCellHeight(for: identifier) {
            calculateCount += 1
            return 100.0
        }

        XCTAssertEqual(height, 100.0)
        XCTAssertEqual(calculateCount, 1)
    }

    func testStartAndEndTimingRecordsOperation() {
        let operation = "test_operation"
        sut.startTiming(operation)
        Thread.sleep(forTimeInterval: 0.01)
        sut.endTiming(operation)

        let summary = sut.getPerformanceSummary()
        XCTAssertTrue(summary.contains(operation))
        XCTAssertTrue(summary.contains("1 calls"))
    }

    func testMultipleOperationsRecordedSeparately() {
        sut.startTiming("op1")
        sut.endTiming("op1")
        sut.startTiming("op2")
        sut.endTiming("op2")

        let summary = sut.getPerformanceSummary()
        XCTAssertTrue(summary.contains("op1"))
        XCTAssertTrue(summary.contains("op2"))
    }

    func testResetMetricsClearsAllMetrics() {
        sut.startTiming("op1")
        sut.endTiming("op1")
        sut.resetMetrics()

        let summary = sut.getPerformanceSummary()
        XCTAssertFalse(summary.contains("op1"))
    }

    func testGetMemoryUsageReturnsValidValues() {
        let memory = sut.getMemoryUsage()
        XCTAssertGreaterThan(memory.used, 0)
        XCTAssertGreaterThan(memory.total, 0)
        XCTAssertLessThanOrEqual(memory.used, memory.total)
    }

    func testMemoryUsagePercentageCalculation() {
        let memory = sut.getMemoryUsage()
        XCTAssertGreaterThanOrEqual(memory.percentage, 0)
        XCTAssertLessThanOrEqual(memory.percentage, 100)
    }

    func testMemoryUsageFormattedStringNotEmpty() {
        let memory = sut.getMemoryUsage()
        let formatted = memory.formattedString
        XCTAssertFalse(formatted.isEmpty)
        XCTAssertTrue(formatted.contains("MB"))
    }

    func testPerformanceCellHeightCaching() {
        measure {
            for i in 1...100 {
                _ = sut.getCellHeight(for: "cell_\(i)") { 80.0 }
            }
        }
    }

    func testPerformanceMetricsTracking() {
        measure {
            for i in 1...50 {
                sut.startTiming("op_\(i)")
                sut.endTiming("op_\(i)")
            }
        }
        sut.resetMetrics()
    }
}
