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
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
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

    func testPerformanceSummaryReportsMemory() {
        let summary = sut.getPerformanceSummary()
        XCTAssertTrue(summary.contains("Memory:"))
        XCTAssertTrue(summary.contains("MB"))
    }
}
