//
//  SiteRackingTests.swift
//  Systems InspectorTests
//

import XCTest
@testable import Systems_Inspector

final class SiteRackingTests: XCTestCase {
    func testEmptyJSONRoundTripIsNil() {
        XCTAssertTrue(SiteRacking.empty.isEmpty)
        XCTAssertNil(SiteRacking.empty.jsonData())
        XCTAssertEqual(SiteRacking.from(jsonData: nil), .empty)
    }

    func testUprightsOnlyIsInvalid() {
        var spec = SiteRacking.empty
        spec.uprights.rows = [UprightSpec(manufacturer: "Interlake")]
        XCTAssertEqual(
            spec.validationMessage(),
            "Beams are required when Uprights are recorded."
        )
    }

    func testBeamsOnlyIsInvalid() {
        var spec = SiteRacking.empty
        spec.beams.rows = [BeamSpec(manufacturer: "Interlake")]
        XCTAssertEqual(
            spec.validationMessage(),
            "Uprights are required when Beams are recorded."
        )
    }

    func testPairedUprightsAndBeamsValid() {
        var spec = SiteRacking.empty
        spec.uprights.rows = [UprightSpec(manufacturer: "Interlake")]
        spec.beams.rows = [BeamSpec(manufacturer: "Interlake")]
        XCTAssertNil(spec.validationMessage())
        XCTAssertFalse(spec.isEmpty)
    }

    func testDecksOnlyIsValid() {
        var spec = SiteRacking.empty
        spec.decks.rows = [DeckSpec(manufacturer: "Interlake", type: "wire")]
        XCTAssertNil(spec.validationMessage())
    }

    func testDeckWithoutTypeIsInvalid() {
        var spec = SiteRacking.empty
        spec.decks.rows = [DeckSpec(manufacturer: "Interlake", type: "")]
        XCTAssertEqual(spec.validationMessage(), "Each deck needs a type.")
    }

    func testCanSetStandardizedFalseWhenTwoRows() {
        var spec = SiteRacking.empty
        spec.uprights.mode = .mixed
        spec.uprights.rows = [
            UprightSpec(manufacturer: "A"),
            UprightSpec(manufacturer: "B")
        ]
        XCTAssertFalse(spec.canSetUprightsStandardized())
        spec.uprights.rows.removeLast()
        XCTAssertTrue(spec.canSetUprightsStandardized())
    }

    func testJSONRoundTripPreservesFields() {
        var spec = SiteRacking.empty
        spec.uprights.mode = .mixed
        spec.uprights.rows = [
            UprightSpec(manufacturer: "Interlake", height: "16'", depth: "42\"", color: "orange")
        ]
        spec.beams.rows = [BeamSpec(manufacturer: "Interlake", length: "8'", color: "orange")]
        spec.decks.rows = [DeckSpec(manufacturer: "Interlake", type: "wire", size: "42x46")]
        let data = spec.jsonData()
        XCTAssertNotNil(data)
        XCTAssertEqual(SiteRacking.from(jsonData: data), spec)
    }

    func testInvalidJSONYieldsEmpty() {
        XCTAssertEqual(SiteRacking.from(jsonData: Data("nope".utf8)), .empty)
    }
}
