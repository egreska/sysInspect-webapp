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
        spec.uprights = SiteRackingSection(rows: [UprightSpec(manufacturer: "Interlake")])
        XCTAssertEqual(
            spec.validationMessage(),
            "Beams are required when Upright Frames are recorded."
        )
    }

    func testBeamsOnlyIsInvalid() {
        var spec = SiteRacking.empty
        spec.beams = SiteRackingSection(rows: [BeamSpec(manufacturer: "Interlake")])
        XCTAssertEqual(
            spec.validationMessage(),
            "Upright Frames are required when Beams are recorded."
        )
    }

    func testPairedUprightsAndBeamsValid() {
        var spec = SiteRacking.empty
        spec.uprights = SiteRackingSection(rows: [UprightSpec(manufacturer: "Interlake")])
        spec.beams = SiteRackingSection(rows: [BeamSpec(manufacturer: "Interlake")])
        XCTAssertNil(spec.validationMessage())
        XCTAssertFalse(spec.isEmpty)
    }

    func testDecksOnlyIsValid() {
        var spec = SiteRacking.empty
        spec.decks = SiteRackingSection(rows: [DeckSpec(manufacturer: "Interlake", type: "wire")])
        XCTAssertNil(spec.validationMessage())
    }

    func testDeckWithoutTypeIsInvalid() {
        var spec = SiteRacking.empty
        spec.decks = SiteRackingSection(rows: [DeckSpec(manufacturer: "Interlake", type: "")])
        XCTAssertEqual(spec.validationMessage(), "Each deck needs a type.")
    }

    func testStandardizedIsAllowedUntilTwoSpecsNameAManufacturer() {
        var uprights = SiteRackingSection(mode: .mixed, rows: [UprightSpec(manufacturer: "A")])
        XCTAssertTrue(uprights.appendBlank())
        XCTAssertTrue(uprights.allowsStandardized)
        uprights.setMode(.standardized)
        XCTAssertEqual(uprights.mode, .standardized)
        XCTAssertEqual(uprights.rows.map(\.manufacturer), ["A"])

        uprights = SiteRackingSection(
            mode: .mixed,
            rows: [UprightSpec(manufacturer: "A"), UprightSpec(manufacturer: "B")]
        )
        XCTAssertFalse(uprights.allowsStandardized)
        uprights.setMode(.standardized)
        XCTAssertEqual(uprights.mode, .mixed)
        XCTAssertEqual(uprights.rows.map(\.manufacturer), ["A", "B"])
    }

    func testAppendAndSeed() {
        var uprights = SiteRackingSection(rows: [UprightSpec(manufacturer: "A")])
        XCTAssertFalse(uprights.appendBlank())
        XCTAssertEqual(uprights.rows.count, 1)
        uprights.setMode(.mixed)
        XCTAssertTrue(uprights.appendBlank())
        XCTAssertEqual(uprights.rows.count, 2)
        XCTAssertFalse(uprights.rows[1].hasManufacturer)
        XCTAssertEqual(uprights.rows[0].construction, .structural)

        var decks = SiteRackingSection<DeckSpec>(mode: .mixed)
        XCTAssertTrue(decks.appendBlank())
        XCTAssertEqual(decks.rows.first?.manufacturer, "")
        XCTAssertEqual(decks.rows.first?.type, "")

        var beams = SiteRackingSection<BeamSpec>()
        beams.seedBlankIfEmpty()
        XCTAssertEqual(beams.rows.count, 1)
        XCTAssertFalse(beams.rows[0].hasManufacturer)
        beams.seedBlankIfEmpty()
        XCTAssertEqual(beams.rows.count, 1)
    }

    func testCreationAndLoadDropNamelessSpecsAndCoerceStandardized() {
        let created = SiteRackingSection(
            mode: .standardized,
            rows: [
                UprightSpec(manufacturer: "A"),
                UprightSpec(manufacturer: " "),
                UprightSpec(manufacturer: "B")
            ]
        )
        XCTAssertEqual(created.mode, .mixed)
        XCTAssertEqual(created.rows.map(\.manufacturer), ["A", "B"])

        let json = """
        {"uprights":{"mode":"standardized","rows":[{"manufacturer":"A"},{"manufacturer":" "},{"manufacturer":"B"}]}}
        """
        let loaded = SiteRacking.from(jsonData: Data(json.utf8))
        XCTAssertEqual(loaded.uprights.mode, .mixed)
        XCTAssertEqual(loaded.uprights.rows.map(\.manufacturer), ["A", "B"])
    }

    func testBecomingStandardizedDropsBlanksAndMixedKeepsThem() {
        var section = SiteRackingSection<CrossBarSpec>(mode: .mixed)
        section.seedBlankIfEmpty()
        XCTAssertTrue(section.appendBlank())
        section.setMode(.mixed)
        XCTAssertEqual(section.rows.count, 2)
        section.setMode(.standardized)
        XCTAssertEqual(section.mode, .standardized)
        XCTAssertTrue(section.rows.isEmpty)
        section.seedBlankIfEmpty()
        XCTAssertEqual(section.rows.count, 1)
        XCTAssertFalse(section.rows[0].hasManufacturer)
    }

    func testJSONRoundTripPreservesFields() {
        var spec = SiteRacking.empty
        spec.uprights = SiteRackingSection(mode: .mixed, rows: [
            UprightSpec(
                manufacturer: "Interlake",
                type: "teardrop",
                height: "16'",
                depth: "42\"",
                capacity: "20k",
                construction: .rollFormed
            )
        ])
        spec.beams = SiteRackingSection(rows: [
            BeamSpec(
                manufacturer: "Interlake",
                type: "step",
                length: "8'",
                face: "3.5\"",
                stepDimensions: "1.5\"",
                capacity: "4000"
            )
        ])
        spec.decks = SiteRackingSection(rows: [
            DeckSpec(
                manufacturer: "Interlake",
                capacity: "2500",
                type: "wire",
                udl: true,
                numberOfDecks: "3"
            )
        ])
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
        spec.crossBars = SiteRackingSection(rows: [CrossBarSpec(manufacturer: "Interlake", size: "42\"")])
        spec.anchors = SiteRackingSection(rows: [AnchorSpec(manufacturer: "Hilti", size: "1/2\"")])
        spec.rowSpacers = SiteRackingSection(rows: [RowSpacerSpec(manufacturer: "Interlake", length: "96\"", width: "6\"")])
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
        spec.crossBars.setMode(.mixed)
        XCTAssertTrue(spec.crossBars.appendBlank())
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

    func testSiteInformationSummaryEmpty() {
        XCTAssertEqual(SiteRacking.empty.siteInformationSummary, "Not filled")
    }

    func testSiteInformationSummaryJoinsFilledFields() {
        var spec = SiteRacking.empty
        spec.siteInformation.numberOfBays = "12"
        spec.siteInformation.numberOfBeamLevels = "4"
        XCTAssertEqual(spec.siteInformationSummary, "12 bays · 4 levels")
        spec.siteInformation.beamSpacing = "48\""
        XCTAssertEqual(spec.siteInformationSummary, "12 bays · 4 levels · 48\" spacing")
    }

    func testLoadInformationSummaryEmptyAndFilled() {
        var spec = SiteRacking.empty
        XCTAssertEqual(spec.loadInformationSummary, "Not filled")
        spec.loadInformation.maximumWeight = "2500 lb"
        XCTAssertEqual(spec.loadInformationSummary, "2500 lb")
        spec.loadInformation.storedContents = "pallets"
        spec.loadInformation.palletDimensions = "40x48"
        XCTAssertEqual(spec.loadInformationSummary, "pallets · 2500 lb · 40x48")
    }

    func testDocumentsSummary() {
        XCTAssertEqual(SiteRacking.documentsSummary(count: 0), "No documents")
        XCTAssertEqual(SiteRacking.documentsSummary(count: 1), "1 document")
        XCTAssertEqual(SiteRacking.documentsSummary(count: 3), "3 documents")
    }

    func testManufacturerSectionSummary() {
        var spec = SiteRacking.empty
        XCTAssertEqual(spec.uprightsSummary, "Not filled")
        spec.uprights = SiteRackingSection(rows: [UprightSpec(manufacturer: "Interlake")])
        XCTAssertEqual(spec.uprightsSummary, "Interlake")
        spec.uprights = SiteRackingSection(mode: .mixed, rows: [
            UprightSpec(manufacturer: "A"),
            UprightSpec(manufacturer: "B")
        ])
        XCTAssertEqual(spec.uprightsSummary, "Mixed · 2 manufacturers")
        spec.uprights = SiteRackingSection(mode: .mixed, rows: [UprightSpec(manufacturer: "A")])
        spec.uprights.appendBlank()
        XCTAssertEqual(spec.uprightsSummary, "A")
    }

    func testSafetyClipsSummary() {
        XCTAssertEqual(SiteRacking.empty.safetyClipsSummary, "Not present")
        var spec = SiteRacking.empty
        spec.safetyClips.present = true
        XCTAssertEqual(spec.safetyClipsSummary, "Present")
        spec.safetyClips.neededCount = "12"
        XCTAssertEqual(spec.safetyClipsSummary, "Present · 12 needed")
    }
}
