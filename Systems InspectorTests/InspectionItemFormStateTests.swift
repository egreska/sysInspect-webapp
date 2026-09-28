//
//  InspectionItemFormStateTests.swift
//  Systems InspectorTests
//

import UIKit
import XCTest
@testable import Systems_Inspector

final class InspectionItemFormStateTests: XCTestCase {

    private func pixel() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1)).image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        }
    }

    func testWhitespaceLocationIsInvalid() {
        var form = InspectionItemFormState(location: "   ")
        XCTAssertFalse(form.isValid)
        form.location = "Aisle 1"
        XCTAssertTrue(form.isValid)
    }

    func testPhotosUnchangedUntilPhotosChange() {
        var form = InspectionItemFormState(location: "Aisle")
        XCTAssertFalse(form.photosChanged)
        XCTAssertTrue(form.addPhoto(pixel()))
        XCTAssertTrue(form.photosChanged)
        XCTAssertEqual(form.photos.count, 1)
    }

    func testRemovePhotoMarksChanged() {
        var form = InspectionItemFormState(location: "Aisle", photos: [pixel()], photosChanged: false)
        XCTAssertFalse(form.photosChanged)
        form.removePhoto(at: 0)
        XCTAssertTrue(form.photosChanged)
        XCTAssertTrue(form.photos.isEmpty)
    }

    func testPhotoCap() {
        var form = InspectionItemFormState()
        for _ in 0..<InspectionItem.maxPhotoCount {
            XCTAssertTrue(form.addPhoto(pixel()))
        }
        XCTAssertTrue(form.atPhotoCap)
        XCTAssertFalse(form.addPhoto(pixel()))
        XCTAssertEqual(form.photos.count, InspectionItem.maxPhotoCount)
    }

    func testResetClearsFieldsAndPhotoFlag() {
        var form = InspectionItemFormState(
            location: "Aisle",
            bayNumber: "B1",
            importance: .needsImmediateAttention,
            comments: "Note",
            issues: [Issue.Path(segments: ["Upright"])],
            photos: [pixel()],
            photosChanged: true
        )
        form.reset()
        XCTAssertEqual(form.location, "")
        XCTAssertNil(form.bayNumber)
        XCTAssertEqual(form.importance, .monitor)
        XCTAssertNil(form.comments)
        XCTAssertTrue(form.issues.isEmpty)
        XCTAssertTrue(form.photos.isEmpty)
        XCTAssertFalse(form.photosChanged)
    }

    func testToggleImportanceAndIssueLabels() {
        var form = InspectionItemFormState(issues: [Issue.Path(segments: ["Upright"])])
        XCTAssertEqual(form.importance, .monitor)
        form.toggleImportance()
        XCTAssertEqual(form.importance, .needsImmediateAttention)
        form.toggleImportance()
        XCTAssertEqual(form.importance, .monitor)
        XCTAssertEqual(form.issueDisplayLabels, ["• Upright"])
    }

    func testHasContent() {
        XCTAssertFalse(InspectionItemFormState().hasContent)
        XCTAssertTrue(InspectionItemFormState(location: "Aisle").hasContent)
        XCTAssertTrue(InspectionItemFormState(issues: [Issue.Path(segments: ["Upright"])]).hasContent)
    }
}
