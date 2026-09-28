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
}
