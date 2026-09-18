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
            "Beams are required when Upright Frames are recorded."
        )
    }

    func testBeamsOnlyIsInvalid() {
        var spec = SiteRacking.empty
        spec.beams.rows = [BeamSpec(manufacturer: "Interlake")]
        XCTAssertEqual(
            spec.validationMessage(),
            "Upright Frames are required when Beams are recorded."
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

    func testCanSetCrossBarsStandardizedFalseWhenTwoRows() {
        var spec = SiteRacking.empty
        spec.crossBars.mode = .mixed
        spec.crossBars.rows = [
            CrossBarSpec(manufacturer: "A"),
            CrossBarSpec(manufacturer: "B")
        ]
        XCTAssertFalse(spec.canSetCrossBarsStandardized())
        spec.crossBars.rows.removeLast()
        XCTAssertTrue(spec.canSetCrossBarsStandardized())
    }

    func testJSONRoundTripPreservesFields() {
        var spec = SiteRacking.empty
        spec.uprights.mode = .mixed
        spec.uprights.rows = [
            UprightSpec(
                manufacturer: "Interlake",
                type: "teardrop",
                height: "16'",
                depth: "42\"",
                capacity: "20k",
                construction: .rollFormed
            )
        ]
        spec.beams.rows = [
            BeamSpec(
                manufacturer: "Interlake",
                type: "step",
                length: "8'",
                face: "3.5\"",
                stepDimensions: "1.5\"",
                capacity: "4000"
            )
        ]
        spec.decks.rows = [
            DeckSpec(
                manufacturer: "Interlake",
                capacity: "2500",
                type: "wire",
                udl: true,
                numberOfDecks: "3"
            )
        ]
        let data = spec.jsonData()
        XCTAssertNotNil(data)
        XCTAssertEqual(SiteRacking.from(jsonData: data), spec)
    }

    func testSiteInformationOnlyPersists() {
        var spec = SiteRacking.empty
        spec.siteInformation.numberOfBays = "12"
        spec.siteInformation.numberOfBeamLevels = "4"
        spec.siteInformation.beamSpacing = "48\""
        XCTAssertNil(spec.validationMessage())
        XCTAssertFalse(spec.isEmpty)
        XCTAssertEqual(SiteRacking.from(jsonData: spec.jsonData()), spec)
    }

    func testWhitespaceOnlySiteInformationIsEmpty() {
        var spec = SiteRacking.empty
        spec.siteInformation.numberOfBays = "  "
        XCTAssertTrue(spec.isEmpty)
        XCTAssertNil(spec.jsonData())
    }

    func testLoadInformationOnlyPersists() {
        var spec = SiteRacking.empty
        spec.loadInformation.maximumWeight = "2500 lb"
        spec.loadInformation.palletDimensions = "40x48"
        spec.loadInformation.loadDimensions = "48x40x60"
        spec.loadInformation.storedContents = "auto parts"
        XCTAssertNil(spec.validationMessage())
        XCTAssertFalse(spec.isEmpty)
        XCTAssertEqual(SiteRacking.from(jsonData: spec.jsonData()), spec)
    }

    func testWhitespaceOnlyLoadInformationIsEmpty() {
        var spec = SiteRacking.empty
        spec.loadInformation.maximumWeight = "  "
        XCTAssertTrue(spec.isEmpty)
        XCTAssertNil(spec.jsonData())
    }

    func testCrossBarsAnchorsAndRowSpacersRoundTrip() {
        var spec = SiteRacking.empty
        spec.crossBars.rows = [CrossBarSpec(manufacturer: "Interlake", size: "42\"")]
        spec.anchors.rows = [AnchorSpec(manufacturer: "Hilti", size: "1/2\"")]
        spec.rowSpacers.rows = [RowSpacerSpec(manufacturer: "Interlake", length: "96\"", width: "6\"")]
        XCTAssertNil(spec.validationMessage())
        XCTAssertFalse(spec.isEmpty)
        XCTAssertEqual(SiteRacking.from(jsonData: spec.jsonData()), spec)
    }

    func testSafetyClipsPresentPersists() {
        var spec = SiteRacking.empty
        spec.safetyClips.present = true
        spec.safetyClips.neededCount = "24"
        XCTAssertNil(spec.validationMessage())
        XCTAssertFalse(spec.isEmpty)
        let roundTrip = SiteRacking.from(jsonData: spec.jsonData())
        XCTAssertTrue(roundTrip.safetyClips.present)
        XCTAssertEqual(roundTrip.safetyClips.neededCount, "24")
    }

    func testSafetyClipsNeededCountIsDroppedWhenNotPresent() {
        var spec = SiteRacking.empty
        spec.safetyClips.present = false
        spec.safetyClips.neededCount = "12"
        XCTAssertTrue(spec.isEmpty)
        XCTAssertNil(spec.jsonData())
    }

    func testJSONOmitsManufacturerlessRows() {
        var spec = SiteRacking.empty
        spec.crossBars.rows = [CrossBarSpec(manufacturer: "")]
        spec.loadInformation.maximumWeight = "1000"
        let roundTrip = SiteRacking.from(jsonData: spec.jsonData())
        XCTAssertEqual(roundTrip.loadInformation.maximumWeight, "1000")
        XCTAssertTrue(roundTrip.crossBars.rows.isEmpty)
    }

    func testLegacyJSONWithoutNewCategoriesStillLoads() {
        let json = """
        {"uprights":{"mode":"standardized","rows":[{"manufacturer":"Interlake","height":"16'"}]},"beams":{"mode":"standardized","rows":[{"manufacturer":"Interlake"}]},"decks":{"mode":"standardized","rows":[]}}
        """
        let spec = SiteRacking.from(jsonData: Data(json.utf8))
        XCTAssertEqual(spec.uprights.rows.first?.manufacturer, "Interlake")
        XCTAssertEqual(spec.uprights.rows.first?.height, "16'")
        XCTAssertEqual(spec.uprights.rows.first?.construction, .structural)
        XCTAssertNil(spec.uprights.rows.first?.type)
        XCTAssertEqual(spec.beams.rows.first?.manufacturer, "Interlake")
        XCTAssertNil(spec.beams.rows.first?.face)
        XCTAssertNil(spec.siteInformation.numberOfBays)
        XCTAssertNil(spec.loadInformation.maximumWeight)
        XCTAssertFalse(spec.safetyClips.present)
        XCTAssertTrue(spec.crossBars.rows.isEmpty)
        XCTAssertTrue(spec.anchors.rows.isEmpty)
        XCTAssertTrue(spec.rowSpacers.rows.isEmpty)
    }

    func testLegacyUprightAndBeamJSONIgnoresColor() {
        let json = """
        {"uprights":{"mode":"standardized","rows":[{"manufacturer":"Interlake","height":"16'","depth":"42\\"","color":"orange"}]},"beams":{"mode":"standardized","rows":[{"manufacturer":"Interlake","length":"8'","color":"orange"}]},"decks":{"mode":"standardized","rows":[]}}
        """
        let spec = SiteRacking.from(jsonData: Data(json.utf8))
        XCTAssertEqual(spec.uprights.rows.first?.manufacturer, "Interlake")
        XCTAssertEqual(spec.uprights.rows.first?.height, "16'")
        XCTAssertEqual(spec.uprights.rows.first?.depth, "42\"")
        XCTAssertEqual(spec.uprights.rows.first?.construction, .structural)
        XCTAssertEqual(spec.beams.rows.first?.length, "8'")
        XCTAssertNil(spec.beams.rows.first?.capacity)
    }

    func testLegacyDeckJSONIgnoresSize() {
        let json = """
        {"uprights":{"mode":"standardized","rows":[]},"beams":{"mode":"standardized","rows":[]},"decks":{"mode":"standardized","rows":[{"manufacturer":"Interlake","type":"wire","size":"42x46"}]}}
        """
        let spec = SiteRacking.from(jsonData: Data(json.utf8))
        XCTAssertEqual(spec.decks.rows.first?.manufacturer, "Interlake")
        XCTAssertEqual(spec.decks.rows.first?.type, "wire")
        XCTAssertNil(spec.decks.rows.first?.capacity)
        XCTAssertFalse(spec.decks.rows.first?.udl ?? true)
        XCTAssertNil(spec.decks.rows.first?.numberOfDecks)
    }

    func testInvalidJSONYieldsEmpty() {
        XCTAssertEqual(SiteRacking.from(jsonData: Data("nope".utf8)), .empty)
    }
}
