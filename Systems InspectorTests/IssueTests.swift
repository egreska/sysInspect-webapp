//
//  IssueTests.swift
//  Systems InspectorTests
//

import XCTest
@testable import Systems_Inspector

final class IssueTests: XCTestCase {

    private var damage: Issue.Path { Issue.Path(segments: ["Upright", "Front", "Damage"]) }
    private var rearDamage: Issue.Path { Issue.Path(segments: ["Upright", "Rear", "Damage"]) }
    private var upright: Issue.Path { Issue.Path(segments: ["Upright"]) }
    private var bracing: Issue.Path { Issue.Path(segments: ["Bracing Damage"]) }
    private var bracingHorizontal: Issue.Path { Issue.Path(segments: ["Bracing Damage", "Horizontal"]) }
    private var front: Issue.Path { Issue.Path(segments: ["Upright", "Front"]) }

    func testDamagePathsAreDistinct() {
        XCTAssertNotEqual(damage, rearDamage)
    }

    func testSelectingLeafInfersAncestorFlags() {
        let flags = Issue.flags(from: [damage])
        XCTAssertEqual(flags[.upright], true)
        XCTAssertEqual(flags[.uprightFrontDamage], true)
        XCTAssertEqual(flags[.uprightRearDamage], false)
        XCTAssertEqual(flags[.beam], false)
    }

    func testSelectingParentOnlySetsParentFlag() {
        let flags = Issue.flags(from: [upright])
        XCTAssertEqual(flags[.upright], true)
        XCTAssertEqual(flags[.uprightFrontDamage], false)
    }

    func testEmptySelectionClearsAllFlags() {
        let flags = Issue.flags(from: [])
        XCTAssertTrue(Issue.Flag.allCases.allSatisfy { flags[$0] == false })
    }

    func testLabelsEmptyWhenNoFlags() {
        XCTAssertEqual(Issue.labels(from: Issue.flags(from: [])), [])
    }

    func testLabelsParentOnly() {
        XCTAssertEqual(Issue.labels(from: Issue.flags(from: [upright])), ["• Upright"])
    }

    func testLabelsHierarchicalLeaf() {
        XCTAssertEqual(
            Issue.labels(from: Issue.flags(from: [damage])),
            ["• Upright > Front > Damage"]
        )
    }

    func testLabelsOmitLeafWhenParentFlagOff() {
        var flags = Issue.flags(from: [])
        flags[.uprightFrontDamage] = true
        XCTAssertEqual(Issue.labels(from: flags), [])
    }

    func testLabelsBracingChildAndParentOnly() {
        XCTAssertEqual(
            Issue.labels(from: Issue.flags(from: [bracingHorizontal])),
            ["• Bracing Damage > Horizontal"]
        )
        XCTAssertEqual(
            Issue.labels(from: Issue.flags(from: [bracing])),
            ["• Bracing Damage"]
        )
    }

    func testPrimaryParentLabelUsesCatalogName() {
        XCTAssertEqual(Issue.primaryParentLabel(from: Issue.flags(from: [bracing])), "Bracing Damage")
        XCTAssertEqual(Issue.primaryParentLabel(from: Issue.flags(from: [])), "No Issues")
        XCTAssertEqual(Issue.primaryParentLabel(from: Issue.flags(from: [damage])), "Upright")
    }

    func testRoundTripSelectionToFlagsToLabels() {
        let selected: Set<Issue.Path> = [damage, bracingHorizontal]
        let flags = Issue.flags(from: selected)
        XCTAssertEqual(
            Issue.labels(from: flags),
            ["• Upright > Front > Damage", "• Bracing Damage > Horizontal"]
        )
        let restored = Issue.selectedPaths(from: flags)
        XCTAssertEqual(Issue.flags(from: restored), flags)
    }

    func testDisplayedAsSelectedIncludesAncestors() {
        XCTAssertTrue(Issue.isDisplayedAsSelected(damage, in: [damage]))
        XCTAssertTrue(Issue.isDisplayedAsSelected(front, in: [damage]))
        XCTAssertTrue(Issue.isDisplayedAsSelected(upright, in: [damage]))
        XCTAssertFalse(Issue.isDisplayedAsSelected(rearDamage, in: [damage]))
    }

    func testTogglingOnAddsPathWithoutAncestors() {
        let next = Issue.toggling(damage, in: [])
        XCTAssertEqual(next, [damage] as Set<Issue.Path>)
        XCTAssertFalse(next.contains(upright))
    }

    func testTogglingOffAncestorClearsDescendants() {
        let next = Issue.toggling(upright, in: [damage])
        XCTAssertTrue(next.isEmpty)
    }

    func testTogglingOffExplicitPath() {
        let next = Issue.toggling(upright, in: [upright])
        XCTAssertTrue(next.isEmpty)
    }

    func testCatalogContainsExpectedRoots() {
        XCTAssertEqual(
            Issue.catalog.map(\.path.name),
            ["Upright", "Beam", "Wire Deck", "Base Plate", "Anchors", "Bracing Damage", "Post Protector", "Aisle Guarding"]
        )
    }
}
