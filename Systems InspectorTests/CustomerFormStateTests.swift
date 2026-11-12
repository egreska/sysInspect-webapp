//
//  CustomerFormStateTests.swift
//  Systems InspectorTests
//

import XCTest
@testable import Systems_Inspector

final class CustomerFormStateTests: XCTestCase {

    func testWhitespaceNameIsInvalid() {
        var form = CustomerFormState(name: "   ")
        XCTAssertFalse(form.isValid)
        form.name = "Acme Racks"
        XCTAssertTrue(form.isValid)
    }

    func testEmptyNameIsInvalid() {
        XCTAssertFalse(CustomerFormState().isValid)
    }

    func testSpecAndDocsDoNotAffectValidity() {
        var form = CustomerFormState()
        form.siteRacking.uprights = SiteRackingSection(rows: [UprightSpec(manufacturer: "X")])
        form.siteDocuments = [
            SiteDocumentFile(id: nil, filename: "a.pdf", contentType: "public.pdf", data: Data([1]))
        ]
        XCTAssertFalse(form.isValid)
        form.name = "Acme"
        XCTAssertTrue(form.isValid)
    }

    func testCommitSiteRecordsThePair() {
        var form = CustomerFormState()
        var racking = SiteRacking.empty
        racking.decks = SiteRackingSection(rows: [DeckSpec(manufacturer: "Interlake", type: "wire")])
        let file = SiteDocumentFile(id: nil, filename: "a.pdf", contentType: "public.pdf", data: Data([1]))
        XCTAssertNil(form.commitSite(racking: racking, documents: [file]))
        XCTAssertEqual(form.siteRacking.decks.rows.map(\.manufacturer), ["Interlake"])
        XCTAssertEqual(form.siteDocuments.map(\.filename), ["a.pdf"])
    }

    func testCommitSiteLeavesAnInvalidProfileUnchanged() {
        var form = CustomerFormState()
        let kept = SiteDocumentFile(id: nil, filename: "kept.pdf", contentType: "public.pdf", data: Data([1]))
        form.siteDocuments = [kept]
        var racking = SiteRacking.empty
        racking.uprights = SiteRackingSection(rows: [UprightSpec(manufacturer: "X")])
        XCTAssertEqual(
            form.commitSite(racking: racking, documents: []),
            "Beams are required when Upright Frames are recorded."
        )
        XCTAssertTrue(form.siteRacking.isEmpty)
        XCTAssertEqual(form.siteDocuments.map(\.filename), ["kept.pdf"])
    }

    func testSiteRackingSubtitleUsesTheSiteRackingLine() {
        var form = CustomerFormState()
        form.siteRacking.uprights = SiteRackingSection(rows: [UprightSpec(manufacturer: "Interlake")])
        form.siteDocuments = [
            SiteDocumentFile(id: nil, filename: "a.pdf", contentType: "public.pdf", data: Data([1]))
        ]
        XCTAssertEqual(
            form.siteRackingSubtitle,
            form.siteRacking.customerLine(documentCount: form.siteDocuments.count)
        )
    }
}
