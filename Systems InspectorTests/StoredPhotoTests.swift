//
//  StoredPhotoTests.swift
//  Systems InspectorTests
//

import UIKit
import XCTest
@testable import Systems_Inspector

final class StoredPhotoTests: XCTestCase {

    func testFittingCapsTheLongEdge() {
        let image = solidImage(size: CGSize(width: 3200, height: 1000))
        let fitted = StoredPhoto.fitting(image)
        let longEdge = longEdge(of: fitted)
        XCTAssertLessThanOrEqual(longEdge, StoredPhoto.maxLongEdge)
        XCTAssertGreaterThan(longEdge, 1500)
        XCTAssertNotNil(StoredPhoto.jpegData(from: fitted))
    }

    func testSmallImageIsUnchanged() {
        let image = solidImage(size: CGSize(width: 80, height: 40))
        let fitted = StoredPhoto.fitting(image)
        XCTAssertEqual(fitted.size, image.size)
        XCTAssertEqual(fitted.scale, image.scale)
    }

    func testAddPhotoStoresTheFittedImage() {
        var form = InspectionItemFormState()
        XCTAssertTrue(form.addPhoto(solidImage(size: CGSize(width: 2000, height: 1000))))
        let longEdge = longEdge(of: form.photos[0])
        XCTAssertLessThanOrEqual(longEdge, StoredPhoto.maxLongEdge)
    }

    func testPDFSiteDocumentStaysAPDF() {
        let data = Data([0x25, 0x50, 0x44, 0x46])
        let stored = StoredPhoto.siteDocumentPhoto(data: data, contentType: "public.pdf", filename: "plan.pdf")
        XCTAssertEqual(stored?.data, data)
        XCTAssertEqual(stored?.contentType, "public.pdf")
        XCTAssertEqual(stored?.filename, "plan.pdf")
    }

    func testPNGSiteDocumentBecomesJPEG() throws {
        let png = solidImage(size: CGSize(width: 80, height: 40)).pngData()
        let stored = StoredPhoto.siteDocumentPhoto(
            data: try XCTUnwrap(png),
            contentType: "public.png",
            filename: "nameplate.png"
        )
        XCTAssertEqual(stored?.contentType, "public.jpeg")
        XCTAssertEqual(stored?.filename, "nameplate.jpg")
        XCTAssertNotNil(stored.flatMap { UIImage(data: $0.data) })
    }

    func testThumbnailStaysWithinThePixelCap() throws {
        let data = try XCTUnwrap(solidImage(size: CGSize(width: 800, height: 400)).jpegData(compressionQuality: 0.8))
        let thumb = try XCTUnwrap(StoredPhoto.thumbnail(from: data, maxPixelSize: 40))
        XCTAssertLessThanOrEqual(longEdge(of: thumb), 40)
    }

    private func solidImage(size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    private func longEdge(of image: UIImage) -> CGFloat {
        max(image.size.width * image.scale, image.size.height * image.scale)
    }
}
