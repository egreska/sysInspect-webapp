//
//  PDFTableLayoutTests.swift
//  Systems InspectorTests
//

import XCTest
@testable import Systems_Inspector

final class PDFTableLayoutTests: XCTestCase {

    private func item(
        photos: Int = 0,
        location: String = "Aisle 1",
        secondary: String? = nil,
        importance: String = "Monitor",
        issue: String = "No issues",
        comments: String = ""
    ) -> PDFItemLayoutInput {
        PDFItemLayoutInput(
            photoCount: photos,
            primaryLocation: location,
            secondaryLocation: secondary,
            importance: importance,
            issueText: issue,
            comments: comments
        )
    }

    private func kinds(_ layout: PDFResolvedTableLayout) -> [PDFTableColumnKind] {
        layout.columns.map(\.kind)
    }

    private func width(_ layout: PDFResolvedTableLayout, _ kind: PDFTableColumnKind) -> CGFloat {
        guard let value = layout.width(for: kind) else {
            XCTFail("missing column \(kind)")
            return 0
        }
        return value
    }

    func testOmitsImageAndCommentsAndSecondaryWhenThoseFieldsAreEmpty() {
        let layout = PDFResolvedTableLayout.resolve(items: [item()])
        XCTAssertEqual(kinds(layout), [.primaryLocation, .importance, .issue])
        XCTAssertEqual(layout.totalWidth, PDFLayoutOptions.tableContentWidth, accuracy: 0.5)
    }

    func testIncludesCommentsWhenAnyItemHasComments() {
        let layout = PDFResolvedTableLayout.resolve(items: [
            item(),
            item(comments: "Surface rust on lower beam")
        ])
        XCTAssertTrue(kinds(layout).contains(.comments))
        XCTAssertFalse(kinds(layout).contains(.image))
        XCTAssertFalse(kinds(layout).contains(.secondaryLocation))
    }

    func testIncludesSecondaryWhenAnyItemHasBayOrLevel() {
        let layout = PDFResolvedTableLayout.resolve(
            items: [item(secondary: "Bay 12")],
            forceSecondaryLocation: false
        )
        XCTAssertTrue(kinds(layout).contains(.secondaryLocation))
    }

    func testForceSecondaryIncludesColumnEvenWithoutBayData() {
        let layout = PDFResolvedTableLayout.resolve(
            items: [item()],
            forceSecondaryLocation: true
        )
        XCTAssertTrue(kinds(layout).contains(.secondaryLocation))
    }

    func testIncludesImageWhenAnyItemHasPhotos() {
        let layout = PDFResolvedTableLayout.resolve(items: [item(photos: 1)])
        XCTAssertEqual(kinds(layout).first, .image)
    }

    func testImageColumnWidensAsMaxPhotoCountIncreases() {
        let one = PDFResolvedTableLayout.resolve(items: [item(photos: 1)])
        let two = PDFResolvedTableLayout.resolve(items: [item(photos: 2)])
        let five = PDFResolvedTableLayout.resolve(items: [item(photos: 1), item(photos: 5)])
        XCTAssertEqual(width(two, .image), width(one, .image), accuracy: 0.5)
        XCTAssertGreaterThan(width(five, .image), width(two, .image))
    }

    func testCompactImageColumnIsNarrowerThanWide() {
        let compact = PDFResolvedTableLayout.resolve(items: [item(photos: 2)], preset: .compact)
        let wide = PDFResolvedTableLayout.resolve(items: [item(photos: 2)], preset: .wide)
        XCTAssertLessThan(width(compact, .image), width(wide, .image))
    }

    func testLongCommentsGetMoreWidthThanShortIssues() {
        let longComments = String(repeating: "comments ", count: 40)
        let layout = PDFResolvedTableLayout.resolve(items: [
            item(issue: "Beam", comments: longComments)
        ])
        XCTAssertGreaterThan(width(layout, .comments), width(layout, .issue))
    }

    func testLongIssuesGetMoreWidthThanShortComments() {
        let longIssues = (1...12).map { "• Upright > Front > Damage line \($0)" }.joined(separator: "\n")
        let layout = PDFResolvedTableLayout.resolve(items: [
            item(issue: longIssues, comments: "ok")
        ])
        XCTAssertGreaterThan(width(layout, .issue), width(layout, .comments))
    }

    func testRowHeightGrowsWithWrappedComments() {
        let short = PDFResolvedTableLayout.resolve(items: [item(comments: "ok")])
        let longInput = item(comments: String(repeating: "Need to replace damaged beam section. ", count: 20))
        let long = PDFResolvedTableLayout.resolve(items: [longInput])
        XCTAssertGreaterThan(long.rowHeight(for: longInput), short.rowHeight(for: item(comments: "ok")))
    }

    func testRowHeightGrowsWithMorePhotos() {
        let oneInput = item(photos: 1, comments: "note")
        let fiveInput = item(photos: 5, comments: "note")
        let one = PDFResolvedTableLayout.resolve(items: [oneInput])
        let five = PDFResolvedTableLayout.resolve(items: [fiveInput])
        XCTAssertGreaterThan(five.rowHeight(for: fiveInput), one.rowHeight(for: oneInput))
    }

    func testPhotoThumbSizeIsTheSameForOnePhotoAndThreePhotosInTheSameTable() {
        let oneInput = item(photos: 1)
        let threeInput = item(photos: 3)
        let layout = PDFResolvedTableLayout.resolve(items: [oneInput, threeInput])
        let imageWidth = width(layout, .image)
        let bounds = CGRect(
            x: 0,
            y: 0,
            width: imageWidth - PDFResolvedTableLayout.cellInset,
            height: 400
        )
        let oneRects = PDFResolvedTableLayout.photoRects(count: 1, in: bounds)
        let threeRects = PDFResolvedTableLayout.photoRects(count: 3, in: bounds)
        XCTAssertEqual(oneRects.count, 1)
        XCTAssertEqual(threeRects.count, 3)
        XCTAssertEqual(oneRects[0].width, threeRects[0].width, accuracy: 0.5)
        XCTAssertEqual(oneRects[0].height, threeRects[0].height, accuracy: 0.5)
        XCTAssertEqual(threeRects[0].size, threeRects[1].size)
        XCTAssertEqual(threeRects[0].size, threeRects[2].size)
        XCTAssertLessThan(oneRects[0].width, bounds.width * 0.7)
        XCTAssertGreaterThan(layout.rowHeight(for: threeInput), layout.rowHeight(for: oneInput))
        XCTAssertLessThan(layout.rowHeight(for: oneInput), imageWidth)
    }

    func testColumnOrderPlacesFlexibleTextLast() {
        let layout = PDFResolvedTableLayout.resolve(items: [
            item(photos: 1, secondary: "B2", comments: "note")
        ])
        XCTAssertEqual(
            kinds(layout),
            [.image, .primaryLocation, .secondaryLocation, .importance, .issue, .comments]
        )
    }

    func testOmitsDateColumnByDefault() {
        let layout = PDFResolvedTableLayout.resolve(items: [item()])
        XCTAssertFalse(kinds(layout).contains(.date))
    }

    func testIncludesDateColumnWhenRequested() {
        let layout = PDFResolvedTableLayout.resolve(
            items: [item()],
            includeInspectionDate: true
        )
        XCTAssertTrue(kinds(layout).contains(.date))
        XCTAssertEqual(layout.totalWidth, PDFLayoutOptions.tableContentWidth, accuracy: 0.5)
    }

    func testDateColumnFollowsImageWhenBothArePresent() {
        let layout = PDFResolvedTableLayout.resolve(
            items: [item(photos: 1)],
            includeInspectionDate: true
        )
        XCTAssertEqual(kinds(layout).prefix(2).map { $0 }, [.image, .date])
    }
}
