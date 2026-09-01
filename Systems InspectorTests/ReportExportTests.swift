//
//  ReportExportTests.swift
//  Systems InspectorTests
//

import PDFKit
import UIKit
import XCTest
@testable import Systems_Inspector

final class ReportExportTests: XCTestCase {

    var generator: ReportGenerator!

    override func setUp() {
        super.setUp()
        generator = ReportGenerator()
    }

    override func tearDown() {
        generator = nil
        super.tearDown()
    }

    private func header() -> ReportHeader {
        ReportHeader(companyName: "Header Co", inspectorName: "Snap Inspector")
    }

    private func item(
        id: UUID = UUID(),
        sequence: Int32 = 1,
        location: String = "Aisle",
        issues: Set<Issue.Path> = [Issue.Path(segments: ["Upright"])],
        photos: [Data] = [],
        comments: String? = nil
    ) -> ReportItemSnapshot {
        ReportItemSnapshot(
            id: id,
            sequenceNumber: sequence,
            location: location,
            bayNumber: nil,
            importance: "Monitor",
            comments: comments,
            issues: issues,
            photos: photos
        )
    }

    private func inspection(
        customerID: String = "customer-1",
        name: String = "Acme",
        site: String? = "Warehouse A",
        date: Date = Date(),
        items: [ReportItemSnapshot]? = nil
    ) -> ReportInspectionSnapshot {
        ReportInspectionSnapshot(
            date: date,
            inspectorName: "Pat",
            customer: ReportCustomerSnapshot(id: customerID, name: name, site: site, address: "1 Main"),
            items: items ?? [item()]
        )
    }

    private func package(from result: ReportExportResult, file: StaticString = #filePath, line: UInt = #line) -> ReportPackage? {
        guard case .package(let package) = result else {
            XCTFail("expected package, got \(result)", file: file, line: line)
            return nil
        }
        return package
    }

    private func jpegPixel() -> Data {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).image { ctx in
            UIColor.blue.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        }
        return image.jpegData(compressionQuality: 0.8) ?? Data()
    }

    func testCSVIncludesHeaderAndIssueStrings() {
        let result = generator.export(ReportRequest(inspections: [inspection()], format: .csv, header: header()))
        let package = package(from: result)
        XCTAssertTrue(package?.fileName.hasSuffix(".csv") == true)
        let text = String(data: package?.data ?? Data(), encoding: .utf8) ?? ""
        XCTAssertTrue(text.contains("# Company: Header Co"), text)
        XCTAssertTrue(text.contains("# Inspector: Snap Inspector"), text)
        XCTAssertTrue(text.contains("• Upright"), text)
        XCTAssertNil(package?.companionData)
    }

    func testPDFWithOneInspectionReturnsNonEmptyData() {
        let result = generator.export(ReportRequest(inspections: [inspection()], format: .pdf, header: header()))
        let package = package(from: result)
        XCTAssertFalse(package?.data.isEmpty ?? true)
        XCTAssertTrue(package?.fileName.hasSuffix(".pdf") == true)
        XCTAssertNil(package?.companionData)
    }

    func testPDFWithZeroInspectionsReturnsEmpty() {
        let result = generator.export(ReportRequest(inspections: [], format: .pdf, header: header()))
        XCTAssertEqual(result, .empty)
    }

    func testPDFJoinRuleAllowsSameCustomerAndSite() {
        XCTAssertTrue(CombinedPDFJoinRule.canJoin([
            inspection(customerID: "a", site: "Warehouse A"),
            inspection(customerID: "a", site: "Warehouse A")
        ]))
    }

    func testPDFJoinRuleAllowsSameCustomerWithEmptySites() {
        XCTAssertTrue(CombinedPDFJoinRule.canJoin([
            inspection(customerID: "a", site: nil),
            inspection(customerID: "a", site: nil)
        ]))
    }

    func testPDFJoinRuleRejectsDifferentCustomers() {
        XCTAssertFalse(CombinedPDFJoinRule.canJoin([
            inspection(customerID: "a"),
            inspection(customerID: "b")
        ]))
    }

    func testPDFJoinRuleRejectsDifferentSites() {
        XCTAssertFalse(CombinedPDFJoinRule.canJoin([
            inspection(customerID: "a", name: "Acme", site: "Warehouse A"),
            inspection(customerID: "a", name: "Acme", site: "Warehouse B")
        ]))
    }

    func testPDFWithTwoInspectionsDifferentCustomersReturnsJoinFailed() {
        let result = generator.export(ReportRequest(
            inspections: [inspection(customerID: "a"), inspection(customerID: "b")],
            format: .pdf,
            header: header()
        ))
        XCTAssertEqual(result, .joinFailed)
    }

    func testPDFWithTwoInspectionsDifferentSitesReturnsJoinFailed() {
        let result = generator.export(ReportRequest(
            inspections: [
                inspection(customerID: "a", site: "Warehouse A"),
                inspection(customerID: "a", site: "Warehouse B")
            ],
            format: .pdf,
            header: header()
        ))
        XCTAssertEqual(result, .joinFailed)
    }

    func testPDFWithTwoInspectionsSameCustomerAndSiteReturnsData() {
        let result = generator.export(ReportRequest(
            inspections: [
                inspection(customerID: "a", site: "Warehouse A"),
                inspection(customerID: "a", site: "Warehouse A")
            ],
            format: .pdf,
            header: header()
        ))
        let package = package(from: result)
        XCTAssertFalse(package?.data.isEmpty ?? true)
        XCTAssertTrue(package?.fileName.hasSuffix(".pdf") == true)
        XCTAssertTrue(package?.fileName.contains("Acme") == true)
    }

    func testPDFWithTwoInspectionsSameCustomerEmptySitesReturnsData() {
        let result = generator.export(ReportRequest(
            inspections: [
                inspection(customerID: "a", site: nil),
                inspection(customerID: "a", site: nil)
            ],
            format: .pdf,
            header: header()
        ))
        if case .package = result {} else {
            XCTFail("expected package, got \(result)")
        }
    }

    func testCSVWithNoInspectionsReturnsEmpty() {
        let result = generator.export(ReportRequest(inspections: [], format: .csv, header: header()))
        XCTAssertEqual(result, .empty)
    }

    func testCSVListsNumberedPhotoFilesForMultipleShots() {
        let photo = jpegPixel()
        let shot = inspection(items: [item(photos: [photo, photo])])
        let result = generator.export(ReportRequest(inspections: [shot], format: .csv, header: header()))
        let package = package(from: result)
        let text = String(data: package?.data ?? Data(), encoding: .utf8) ?? ""
        XCTAssertTrue(text.contains("_1.jpg"), text)
        XCTAssertTrue(text.contains("_2.jpg"), text)
        XCTAssertEqual(package?.companionFileName?.hasSuffix(".zip"), true)
        Self.assertStoredZip(package?.companionData)
        let zipLatin = String(data: package?.companionData ?? Data(), encoding: .isoLatin1) ?? ""
        XCTAssertTrue(zipLatin.contains("_1.jpg"), zipLatin)
        XCTAssertTrue(zipLatin.contains("_2.jpg"), zipLatin)
    }

    func testPDFWithManyItemsReturnsMultiPageData() {
        var items: [ReportItemSnapshot] = [item()]
        for index in 0..<20 {
            items.append(item(
                sequence: Int32(index + 2),
                location: "Aisle \(index)",
                issues: [],
                comments: "Overflow comment for pagination."
            ))
        }
        let result = generator.export(ReportRequest(
            inspections: [inspection(items: items)],
            format: .pdf,
            header: header()
        ))
        let package = package(from: result)
        XCTAssertFalse(package?.data.isEmpty ?? true)
        let pageCount = PDFDocument(data: package?.data ?? Data())?.pageCount ?? 0
        XCTAssertGreaterThan(pageCount, 1, "expected pagination, got \(pageCount) page(s)")
        XCTAssertNil(package?.companionData)
    }

    private static func assertStoredZip(_ data: Data?, file: StaticString = #filePath, line: UInt = #line) {
        guard let data, data.count >= 22 else {
            XCTFail("companion is not a ZIP", file: file, line: line)
            return
        }
        XCTAssertEqual(Array(data.prefix(4)), [0x50, 0x4B, 0x03, 0x04], file: file, line: line)
        XCTAssertEqual(Array(data.suffix(22).prefix(4)), [0x50, 0x4B, 0x05, 0x06], file: file, line: line)
    }
}
