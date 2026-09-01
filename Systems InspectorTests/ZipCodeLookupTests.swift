//
//  ZipCodeLookupTests.swift
//  Systems InspectorTests
//

import XCTest
@testable import Systems_Inspector

final class ZipCodeLookupTests: XCTestCase {

    func testKnownZipReturnsCityState() {
        let result = ZipCodeLookup.cityState(for: "75201")
        XCTAssertEqual(result?.city, "Dallas")
        XCTAssertEqual(result?.state, "TX")
    }

    func testUnknownZipReturnsNil() {
        XCTAssertNil(ZipCodeLookup.cityState(for: "00000"))
    }
}
