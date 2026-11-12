//
//  ImageCacheManagerTests.swift
//  Systems InspectorTests
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
        testImage = createTestImage(size: CGSize(width: 100, height: 100), color: .red)
        sut.clearMemoryCache()
    }

    override func tearDown() {
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

    private func jpegData(from image: UIImage) -> Data {
        image.jpegData(compressionQuality: 0.8) ?? Data()
    }

    func testCacheImageInMemory() {
        sut.cacheImage(testImage, forKey: testKey)

        XCTAssertNotNil(sut.getImageFromMemory(forKey: testKey))
    }

    func testGetImageFromMemoryReturnsNilWhenNotCached() {
        XCTAssertNil(sut.getImageFromMemory(forKey: "nonexistent"))
    }

    func testClearMemoryCacheRemovesImages() {
        sut.cacheImage(testImage, forKey: testKey)
        XCTAssertNotNil(sut.getImageFromMemory(forKey: testKey))

        sut.clearMemoryCache()

        XCTAssertNil(sut.getImageFromMemory(forKey: testKey))
    }

    func testGetImageDecodesDataIntoMemory() {
        let expectation = expectation(description: "Decode into memory")

        sut.getImage(forKey: testKey, data: jpegData(from: testImage)) { image in
            XCTAssertNotNil(image)
            expectation.fulfill()
        }

        waitForExpectations(timeout: 2.0)
        XCTAssertNotNil(sut.getImageFromMemory(forKey: testKey))
    }

    func testGetImageMissesWhenMemoryIsEmpty() {
        let expectation = expectation(description: "Memory miss")

        sut.getImage(forKey: testKey) { image in
            XCTAssertNil(image)
            expectation.fulfill()
        }

        waitForExpectations(timeout: 2.0)
    }

    func testRemoveImageDropsMemoryAndThumbnail() {
        sut.cacheImage(testImage, forKey: testKey)
        let thumbExpectation = expectation(description: "Thumbnail")
        sut.getThumbnail(forKey: testKey, maxDimension: 300, data: jpegData(from: testImage)) { _ in
            thumbExpectation.fulfill()
        }
        wait(for: [thumbExpectation], timeout: 2.0)
        XCTAssertNotNil(sut.getImageFromMemory(forKey: "thumb_300_\(testKey)"))

        sut.removeImage(forKey: testKey)

        XCTAssertNil(sut.getImageFromMemory(forKey: testKey))
        XCTAssertNil(sut.getImageFromMemory(forKey: "thumb_300_\(testKey)"))
    }

    func testUncachedThumbnailDoesNotStore() {
        let expectation = expectation(description: "Uncached thumbnail")
        let data = jpegData(from: testImage)

        sut.uncachedThumbnail(from: data, maxDimension: 40) { image in
            XCTAssertNotNil(image)
            expectation.fulfill()
        }

        waitForExpectations(timeout: 2.0)
        XCTAssertNil(sut.getImageFromMemory(forKey: testKey))
    }

    func testMemoryClearStaysAMiss() {
        sut.cacheImage(testImage, forKey: testKey)
        sut.clearMemoryCache()

        let expectation = expectation(description: "Still a miss")
        sut.getImage(forKey: testKey) { image in
            XCTAssertNil(image)
            expectation.fulfill()
        }
        waitForExpectations(timeout: 2.0)
    }

    func testPerformanceCachingImages() {
        let images = (1...10).map { _ in
            createTestImage(size: CGSize(width: 50, height: 50), color: .blue)
        }

        measure {
            for (index, image) in images.enumerated() {
                sut.cacheImage(image, forKey: "perf_test_\(index)")
            }
        }

        for index in 0..<10 {
            sut.removeImage(forKey: "perf_test_\(index)")
        }
    }

    func testPerformanceMemoryCacheRetrieval() {
        sut.cacheImage(testImage, forKey: testKey)

        measure {
            for _ in 1...1000 {
                _ = sut.getImageFromMemory(forKey: testKey)
            }
        }
    }
}
