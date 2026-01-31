//
//  PerformanceOptimizerTests.swift
//  Systems InspectorTests
//
//  Unit tests for PerformanceOptimizer
//  Created on 1/29/26.
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
        sut.clearCellHeightCache()
        sut = nil
        super.tearDown()
    }
    
    // MARK: - Cell Height Caching Tests
    
    func testGetCellHeightCalculatesFirstTime() {
        // Given: A cell identifier with no cached height
        let identifier = "test_cell_1"
        var calculateCount = 0
        
        // When: Getting height (will calculate)
        let height = sut.getCellHeight(for: identifier) {
            calculateCount += 1
            return 100.0
        }
        
        // Then: Should calculate once and return correct height
        XCTAssertEqual(height, 100.0)
        XCTAssertEqual(calculateCount, 1, "Should calculate once")
    }
    
    func testGetCellHeightReturnsCachedValue() {
        // Given: A cached cell height
        let identifier = "test_cell_2"
        var calculateCount = 0
        
        _ = sut.getCellHeight(for: identifier) {
            calculateCount += 1
            return 100.0
        }
        
        // When: Getting height again
        let height = sut.getCellHeight(for: identifier) {
            calculateCount += 1
            return 100.0
        }
        
        // Then: Should return cached value without calculating
        XCTAssertEqual(height, 100.0)
        XCTAssertEqual(calculateCount, 1, "Should not calculate again")
    }
    
    func testClearCellHeightCacheRemovesAllHeights() {
        // Given: Multiple cached heights
        _ = sut.getCellHeight(for: "cell_1") { 80.0 }
        _ = sut.getCellHeight(for: "cell_2") { 90.0 }
        _ = sut.getCellHeight(for: "cell_3") { 100.0 }
        
        // When: Clearing cache
        sut.clearCellHeightCache()
        
        var calculateCount = 0
        
        // Then: Should recalculate on next access
        _ = sut.getCellHeight(for: "cell_1") {
            calculateCount += 1
            return 80.0
        }
        
        XCTAssertEqual(calculateCount, 1, "Should recalculate after cache clear")
    }
    
    // MARK: - Computed Value Caching Tests
    
    func testCacheValueStoresValue() {
        // Given: A value to cache
        let testValue = "test_data"
        let key = "test_key"
        
        // When: Caching the value
        sut.cacheValue(testValue, forKey: key, ttl: 60)
        
        // Then: Should be retrievable
        let retrieved = sut.getCachedValue(forKey: key) as? String
        XCTAssertEqual(retrieved, testValue)
    }
    
    func testGetCachedValueReturnsNilForNonexistent() {
        // Given: No cached value
        
        // When: Getting nonexistent key
        let value = sut.getCachedValue(forKey: "nonexistent")
        
        // Then: Should return nil
        XCTAssertNil(value)
    }
    
    func testCachedValueExpiresAfterTTL() {
        // Given: Value with very short TTL
        let testValue = "expires_soon"
        let key = "expiring_key"
        
        sut.cacheValue(testValue, forKey: key, ttl: 0.1) // 0.1 second TTL
        
        // Wait for expiration
        Thread.sleep(forTimeInterval: 0.2)
        
        // When: Getting expired value
        let retrieved = sut.getCachedValue(forKey: key)
        
        // Then: Should return nil (expired)
        XCTAssertNil(retrieved, "Expired value should return nil")
    }
    
    func testClearExpiredCacheRemovesOnlyExpired() {
        // Given: Mix of expired and valid values
        sut.cacheValue("valid", forKey: "valid_key", ttl: 60)
        sut.cacheValue("expired", forKey: "expired_key", ttl: 0.1)
        
        Thread.sleep(forTimeInterval: 0.2)
        
        // When: Clearing expired cache
        sut.clearExpiredCache()
        
        // Then: Valid should remain, expired should be gone
        XCTAssertNotNil(sut.getCachedValue(forKey: "valid_key"))
        XCTAssertNil(sut.getCachedValue(forKey: "expired_key"))
    }
    
    // MARK: - Performance Metrics Tests
    
    func testStartAndEndTimingRecordsOperation() {
        // Given: An operation name
        let operation = "test_operation"
        
        // When: Timing an operation
        sut.startTiming(operation)
        Thread.sleep(forTimeInterval: 0.01) // 10ms
        sut.endTiming(operation)
        
        // Then: Should be recorded in summary
        let summary = sut.getPerformanceSummary()
        XCTAssertTrue(summary.contains(operation), "Summary should contain operation")
        XCTAssertTrue(summary.contains("1 calls"), "Should show 1 call")
    }
    
    func testMultipleOperationsRecordedSeparately() {
        // Given: Multiple operations
        sut.startTiming("op1")
        sut.endTiming("op1")
        
        sut.startTiming("op2")
        sut.endTiming("op2")
        
        // When: Getting summary
        let summary = sut.getPerformanceSummary()
        
        // Then: Should show both operations
        XCTAssertTrue(summary.contains("op1"))
        XCTAssertTrue(summary.contains("op2"))
    }
    
    func testResetMetricsClearsAllMetrics() {
        // Given: Recorded operations
        sut.startTiming("op1")
        sut.endTiming("op1")
        
        // When: Resetting metrics
        sut.resetMetrics()
        
        // Then: Summary should be minimal
        let summary = sut.getPerformanceSummary()
        XCTAssertFalse(summary.contains("op1"), "Should not contain reset operation")
    }
    
    // MARK: - Memory Usage Tests
    
    func testGetMemoryUsageReturnsValidValues() {
        // When: Getting memory usage
        let memory = sut.getMemoryUsage()
        
        // Then: Should have reasonable values
        XCTAssertGreaterThan(memory.used, 0, "Used memory should be positive")
        XCTAssertGreaterThan(memory.total, 0, "Total memory should be positive")
        XCTAssertLessThanOrEqual(memory.used, memory.total, "Used should not exceed total")
    }
    
    func testMemoryUsagePercentageCalculation() {
        // Given: Memory usage
        let memory = sut.getMemoryUsage()
        
        // Then: Percentage should be between 0 and 100
        XCTAssertGreaterThanOrEqual(memory.percentage, 0)
        XCTAssertLessThanOrEqual(memory.percentage, 100)
    }
    
    func testMemoryUsageFormattedStringNotEmpty() {
        // Given: Memory usage
        let memory = sut.getMemoryUsage()
        
        // When: Getting formatted string
        let formatted = memory.formattedString
        
        // Then: Should not be empty
        XCTAssertFalse(formatted.isEmpty)
        XCTAssertTrue(formatted.contains("MB"))
    }
    
    // MARK: - Batch Processing Tests
    
    func testBatchProcessHandlesEmptyArray() {
        // Given: Empty array
        let items: [Int] = []
        var processedCount = 0
        
        let expectation = self.expectation(description: "Batch processing")
        
        // When: Batch processing
        sut.batchProcess(
            items: items,
            batchSize: 10,
            process: { batch in
                processedCount += batch.count
            },
            completion: {
                expectation.fulfill()
            }
        )
        
        waitForExpectations(timeout: 2.0)
        
        // Then: Should complete without processing anything
        XCTAssertEqual(processedCount, 0)
    }
    
    func testBatchProcessDividesIntoChunks() {
        // Given: Array of items
        let items = Array(1...25)
        var batchCount = 0
        
        let expectation = self.expectation(description: "Batch processing")
        
        // When: Batch processing with batch size 10
        sut.batchProcess(
            items: items,
            batchSize: 10,
            process: { batch in
                batchCount += 1
            },
            completion: {
                expectation.fulfill()
            }
        )
        
        waitForExpectations(timeout: 2.0)
        
        // Then: Should create 3 batches (10, 10, 5)
        XCTAssertEqual(batchCount, 3, "Should create 3 batches")
    }
    
    func testBatchProcessProcessesAllItems() {
        // Given: Array of items
        let items = Array(1...25)
        var processedItems: [Int] = []
        
        let expectation = self.expectation(description: "Batch processing")
        
        // When: Batch processing
        sut.batchProcess(
            items: items,
            batchSize: 10,
            process: { batch in
                processedItems.append(contentsOf: batch)
            },
            completion: {
                expectation.fulfill()
            }
        )
        
        waitForExpectations(timeout: 2.0)
        
        // Then: Should process all items
        XCTAssertEqual(processedItems.count, 25)
        XCTAssertEqual(Set(processedItems), Set(items))
    }
    
    // MARK: - Performance Tests
    
    func testPerformanceCellHeightCaching() {
        measure {
            for i in 1...100 {
                _ = sut.getCellHeight(for: "cell_\(i)") { 80.0 }
            }
        }
        
        sut.clearCellHeightCache()
    }
    
    func testPerformanceValueCaching() {
        measure {
            for i in 1...100 {
                sut.cacheValue("value_\(i)", forKey: "key_\(i)", ttl: 60)
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
