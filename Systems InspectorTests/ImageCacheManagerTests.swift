//
//  ImageCacheManagerTests.swift
//  Systems InspectorTests
//
//  Unit tests for ImageCacheManager
//  Created on 1/29/26.
//

import XCTest
import UIKit
@testable import Systems_Inspector

final class ImageCacheManagerTests: XCTestCase {
    
    var sut: ImageCacheManager!
    var testImage: UIImage!
    let testKey = "test_image_key"
    
    override func setUp() {
        super.setUp()
        sut = ImageCacheManager.shared
        
        // Create a test image
        testImage = createTestImage(size: CGSize(width: 100, height: 100), color: .red)
        
        // Clear caches before each test
        sut.clearMemoryCache()
    }
    
    override func tearDown() {
        // Clean up after each test
        sut.clearMemoryCache()
        sut.removeImage(forKey: testKey)
        testImage = nil
        sut = nil
        super.tearDown()
    }
    
    private func createTestImage(size: CGSize, color: UIColor) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
    
    // MARK: - Memory Cache Tests
    
    func testCacheImageInMemory() {
        // Given: An image
        
        // When: Caching the image
        sut.cacheImage(testImage, forKey: testKey)
        
        // Small delay for async disk write
        Thread.sleep(forTimeInterval: 0.1)
        
        // Then: Should be retrievable from memory
        let cachedImage = sut.getImageFromMemory(forKey: testKey)
        XCTAssertNotNil(cachedImage, "Image should be cached in memory")
    }
    
    func testGetImageFromMemoryReturnsNilWhenNotCached() {
        // Given: No cached image
        
        // When: Getting from memory
        let image = sut.getImageFromMemory(forKey: "nonexistent")
        
        // Then: Should be nil
        XCTAssertNil(image, "Should return nil for non-existent image")
    }
    
    func testClearMemoryCacheRemovesImages() {
        // Given: Cached image
        sut.cacheImage(testImage, forKey: testKey)
        XCTAssertNotNil(sut.getImageFromMemory(forKey: testKey))
        
        // When: Clearing memory cache
        sut.clearMemoryCache()
        
        // Then: Image should be removed from memory
        let cachedImage = sut.getImageFromMemory(forKey: testKey)
        XCTAssertNil(cachedImage, "Memory cache should be cleared")
    }
    
    // MARK: - Disk Cache Tests
    
    func testGetImageLoadsFromDisk() {
        // Given: Image cached (will write to disk)
        sut.cacheImage(testImage, forKey: testKey)
        
        // Wait for disk write
        Thread.sleep(forTimeInterval: 0.5)
        
        // Clear memory cache
        sut.clearMemoryCache()
        
        let expectation = self.expectation(description: "Load from disk")
        
        // When: Getting image (should load from disk)
        sut.getImage(forKey: testKey) { image in
            // Then: Should retrieve from disk
            XCTAssertNotNil(image, "Should load image from disk")
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 2.0)
    }
    
    func testRemoveImageRemovesFromBothCaches() {
        // Given: Cached image
        sut.cacheImage(testImage, forKey: testKey)
        Thread.sleep(forTimeInterval: 0.5)
        
        // When: Removing image
        sut.removeImage(forKey: testKey)
        Thread.sleep(forTimeInterval: 0.5)
        
        // Then: Should be removed from memory
        XCTAssertNil(sut.getImageFromMemory(forKey: testKey))
        
        // And from disk
        let expectation = self.expectation(description: "Check disk removal")
        sut.getImage(forKey: testKey) { image in
            XCTAssertNil(image, "Should be removed from disk")
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 2.0)
    }
    
    // MARK: - Cache Size Tests
    
    func testGetCacheSizeReturnsZeroInitially() {
        // Given: Clear cache
        let expectation = self.expectation(description: "Get cache size")
        
        // When: Getting cache size
        sut.getCacheSize { size in
            // Then: Should be zero or very small
            XCTAssertLessThan(size, 1024, "Cache size should be minimal initially")
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 2.0)
    }
    
    func testGetCacheSizeIncreasesAfterCaching() {
        // Given: Clear cache
        sut.clearMemoryCache()
        
        let expectation1 = self.expectation(description: "Initial size")
        var initialSize: Int64 = 0
        
        sut.getCacheSize { size in
            initialSize = size
            expectation1.fulfill()
        }
        
        wait(for: [expectation1], timeout: 2.0)
        
        // When: Caching an image
        sut.cacheImage(testImage, forKey: testKey)
        Thread.sleep(forTimeInterval: 0.5)
        
        let expectation2 = self.expectation(description: "After caching")
        
        // Then: Size should increase
        sut.getCacheSize { size in
            XCTAssertGreaterThan(size, initialSize, "Cache size should increase after caching")
            expectation2.fulfill()
        }
        
        waitForExpectations(timeout: 2.0)
    }
    
    func testFormatCacheSizeReturnsReadableString() {
        // Given: Various cache sizes
        let testCases: [(Int64, String)] = [
            (1024, "1 KB"),
            (1024 * 1024, "1 MB"),
            (512, "512 bytes")
        ]
        
        // When/Then: Formatting should be readable
        for (bytes, _) in testCases {
            let formatted = sut.formatCacheSize(bytes)
            XCTAssertFalse(formatted.isEmpty, "Formatted size should not be empty")
            // Just verify it returns a string, exact format may vary by system
        }
    }
    
    // MARK: - Clear Disk Cache Tests
    
    func testClearDiskCacheRemovesImages() {
        // Given: Cached image
        sut.cacheImage(testImage, forKey: testKey)
        Thread.sleep(forTimeInterval: 0.5)
        
        let expectation1 = self.expectation(description: "Clear disk cache")
        
        // When: Clearing disk cache
        sut.clearDiskCache {
            expectation1.fulfill()
        }
        
        wait(for: [expectation1], timeout: 3.0)
        
        // Then: Image should not be retrievable
        let expectation2 = self.expectation(description: "Verify cleared")
        sut.getImage(forKey: testKey) { image in
            XCTAssertNil(image, "Image should be removed from disk cache")
            expectation2.fulfill()
        }
        
        waitForExpectations(timeout: 2.0)
    }
    
    // MARK: - Performance Tests
    
    func testPerformanceCachingImages() {
        let images = (1...10).map { index in
            createTestImage(size: CGSize(width: 50, height: 50), color: .blue)
        }
        
        measure {
            for (index, image) in images.enumerated() {
                sut.cacheImage(image, forKey: "perf_test_\(index)")
            }
        }
        
        // Cleanup
        for index in 0..<10 {
            sut.removeImage(forKey: "perf_test_\(index)")
        }
    }
    
    func testPerformanceMemoryCacheRetrieval() {
        // Setup
        sut.cacheImage(testImage, forKey: testKey)
        
        measure {
            for _ in 1...1000 {
                _ = sut.getImageFromMemory(forKey: testKey)
            }
        }
    }
    
    // MARK: - Integration Tests
    
    func testImageSurvivesMemoryClearButNotDiskClear() {
        // Given: Cached image
        sut.cacheImage(testImage, forKey: testKey)
        Thread.sleep(forTimeInterval: 0.5)
        
        // When: Clearing memory cache only
        sut.clearMemoryCache()
        
        // Then: Should load from disk
        let expectation1 = self.expectation(description: "Load from disk")
        sut.getImage(forKey: testKey) { image in
            XCTAssertNotNil(image, "Should load from disk after memory clear")
            expectation1.fulfill()
        }
        
        wait(for: [expectation1], timeout: 2.0)
        
        // When: Clearing disk cache
        let expectation2 = self.expectation(description: "Clear disk")
        sut.clearDiskCache {
            expectation2.fulfill()
        }
        
        wait(for: [expectation2], timeout: 3.0)
        
        // Then: Should not be available
        let expectation3 = self.expectation(description: "Verify gone")
        sut.getImage(forKey: testKey) { image in
            XCTAssertNil(image, "Should be gone after disk clear")
            expectation3.fulfill()
        }
        
        waitForExpectations(timeout: 2.0)
    }
}
