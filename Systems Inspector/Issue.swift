//
//  Issue.swift
//  Systems Inspector
//

import Foundation

enum Issue {
    struct Path: Hashable {
        var segments: [String]

        var name: String { segments.last ?? "" }

        func isAncestor(of other: Path) -> Bool {
            other.segments.count > segments.count && other.segments.starts(with: segments)
        }
    }

    struct Node: Equatable {
        var path: Path
        var flag: Flag?
        var children: [Node]
    }

    enum Flag: String, CaseIterable {
        case upright
        case uprightFrontDamage
        case uprightFrontTwisted
        case uprightRearDamage
        case uprightRearTwisted
        case uprightAlignmentOutOfAlignment
        case uprightAlignmentOutOfVerticalPlumb
        case beam
        case beamFrontDamage
        case beamRearDamage
        case beamFrontBowed
        case beamRearBowed
        case wireDeck
        case wireDeckMissing
        case wireDeckDamaged
        case wireDeckOutOfPosition
        case basePlate
        case basePlateFloorDamaged
        case basePlateTwisted
        case basePlateDamaged
        case anchors
        case anchorsMissing
        case anchorsDamaged
        case anchorsTorqued
        case bracingDamage
        case bracingHorizontal
        case bracingDiagonal
        case postProtector
        case postProtectorMissing
        case postProtectorDamaged
        case postProtectorRepairRequired
        case aisleGuarding
        case aisleGuardingMissing
        case aisleGuardingDamaged
        case aisleGuardingRepairRequired
    }

    static let catalog: [Node] = {
        func n(_ segments: [String], _ flag: Flag? = nil, _ children: [Node] = []) -> Node {
            Node(path: Path(segments: segments), flag: flag, children: children)
        }
        return [
            n(["Upright"], .upright, [
                n(["Upright", "Front"], nil, [
                    n(["Upright", "Front", "Damage"], .uprightFrontDamage),
                    n(["Upright", "Front", "Twisted"], .uprightFrontTwisted)
                ]),
                n(["Upright", "Rear"], nil, [
                    n(["Upright", "Rear", "Damage"], .uprightRearDamage),
                    n(["Upright", "Rear", "Twisted"], .uprightRearTwisted)
                ]),
                n(["Upright", "Alignment"], nil, [
                    n(["Upright", "Alignment", "Out of alignment"], .uprightAlignmentOutOfAlignment),
                    n(["Upright", "Alignment", "Out of vertical plumb"], .uprightAlignmentOutOfVerticalPlumb)
                ])
            ]),
            n(["Beam"], .beam, [
                n(["Beam", "Front damage"], .beamFrontDamage),
                n(["Beam", "Rear damage"], .beamRearDamage),
                n(["Beam", "Front bowed"], .beamFrontBowed),
                n(["Beam", "Rear bowed"], .beamRearBowed)
            ]),
            n(["Wire Deck"], .wireDeck, [
                n(["Wire Deck", "Missing"], .wireDeckMissing),
                n(["Wire Deck", "Damaged"], .wireDeckDamaged),
                n(["Wire Deck", "Out of position"], .wireDeckOutOfPosition)
            ]),
            n(["Base Plate"], .basePlate, [
                n(["Base Plate", "Floor damaged"], .basePlateFloorDamaged),
                n(["Base Plate", "Twisted"], .basePlateTwisted),
                n(["Base Plate", "Damaged"], .basePlateDamaged)
            ]),
            n(["Anchors"], .anchors, [
                n(["Anchors", "Missing anchors or bolts"], .anchorsMissing),
                n(["Anchors", "Damaged or bent"], .anchorsDamaged),
                n(["Anchors", "Torqued to 35lbs"], .anchorsTorqued)
            ]),
            n(["Bracing Damage"], .bracingDamage, [
                n(["Bracing Damage", "Horizontal"], .bracingHorizontal),
                n(["Bracing Damage", "Diagonal"], .bracingDiagonal)
            ]),
            n(["Post Protector"], .postProtector, [
                n(["Post Protector", "Missing"], .postProtectorMissing),
                n(["Post Protector", "Damaged"], .postProtectorDamaged),
                n(["Post Protector", "Repair required"], .postProtectorRepairRequired)
            ]),
            n(["Aisle Guarding"], .aisleGuarding, [
                n(["Aisle Guarding", "Missing"], .aisleGuardingMissing),
                n(["Aisle Guarding", "Damaged"], .aisleGuardingDamaged),
                n(["Aisle Guarding", "Repair required"], .aisleGuardingRepairRequired)
            ])
        ]
    }()

    static func flattened(_ nodes: [Node] = catalog) -> [Node] {
        nodes.flatMap { [$0] + flattened($0.children) }
    }

    static func flags(from selected: Set<Path>) -> [Flag: Bool] {
        var result = Dictionary(uniqueKeysWithValues: Flag.allCases.map { ($0, false) })
        let flagByPath = Dictionary(
            uniqueKeysWithValues: flattened().compactMap { node in
                node.flag.map { (node.path, $0) }
            }
        )
        for path in selected {
            var current: Path? = path
            while let resolved = current {
                if let flag = flagByPath[resolved] {
                    result[flag] = true
                }
                current = resolved.segments.count > 1
                    ? Path(segments: Array(resolved.segments.dropLast()))
                    : nil
            }
        }
        return result
    }

    static func labels(from flags: [Flag: Bool]) -> [String] {
        catalog.flatMap { labels(from: $0, flags: flags, ancestorsRecorded: true) }
    }

    static func primaryParentLabel(from flags: [Flag: Bool]) -> String {
        for node in catalog {
            if let flag = node.flag, flags[flag] == true {
                return node.path.name
            }
        }
        return "No Issues"
    }

    static func selectedPaths(from flags: [Flag: Bool]) -> Set<Path> {
        Set(flattened().compactMap { node in
            guard let flag = node.flag, flags[flag] == true else { return nil }
            return node.path
        })
    }

    static func isDisplayedAsSelected(_ path: Path, in selected: Set<Path>) -> Bool {
        selected.contains(path) || selected.contains { path.isAncestor(of: $0) }
    }

    static func toggling(_ path: Path, in selected: Set<Path>) -> Set<Path> {
        if isDisplayedAsSelected(path, in: selected) {
            return selected.filter { $0 != path && !path.isAncestor(of: $0) }
        }
        return selected.union([path])
    }

    private static func labels(from node: Node, flags: [Flag: Bool], ancestorsRecorded: Bool) -> [String] {
        if let flag = node.flag {
            guard ancestorsRecorded, flags[flag] == true else { return [] }
            let childLabels = node.children.flatMap {
                labels(from: $0, flags: flags, ancestorsRecorded: true)
            }
            if childLabels.isEmpty {
                return [bullet(node.path)]
            }
            return childLabels
        }
        guard ancestorsRecorded else { return [] }
        return node.children.flatMap { labels(from: $0, flags: flags, ancestorsRecorded: true) }
    }

    private static func bullet(_ path: Path) -> String {
        "• " + path.segments.joined(separator: " > ")
    }
}
