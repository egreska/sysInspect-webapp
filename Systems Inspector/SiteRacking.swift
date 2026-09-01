//
//  SiteRacking.swift
//  Systems Inspector
//

import Foundation

enum SiteRackingMode: String, Codable, Equatable {
    case standardized
    case mixed
}

protocol SiteRackingRow {
    var manufacturer: String { get }
}

extension SiteRackingRow {
    var hasManufacturer: Bool {
        !manufacturer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct UprightSpec: Codable, Equatable, SiteRackingRow {
    var manufacturer: String
    var height: String?
    var depth: String?
    var color: String?

    init(manufacturer: String, height: String? = nil, depth: String? = nil, color: String? = nil) {
        self.manufacturer = manufacturer
        self.height = height
        self.depth = depth
        self.color = color
    }
}

struct BeamSpec: Codable, Equatable, SiteRackingRow {
    var manufacturer: String
    var length: String?
    var color: String?

    init(manufacturer: String, length: String? = nil, color: String? = nil) {
        self.manufacturer = manufacturer
        self.length = length
        self.color = color
    }
}

struct DeckSpec: Codable, Equatable, SiteRackingRow {
    var manufacturer: String
    var type: String
    var size: String?

    init(manufacturer: String, type: String, size: String? = nil) {
        self.manufacturer = manufacturer
        self.type = type
        self.size = size
    }
}

struct SiteRackingSection<Row: Codable & Equatable>: Codable, Equatable {
    var mode: SiteRackingMode
    var rows: [Row]

    init(mode: SiteRackingMode = .standardized, rows: [Row] = []) {
        self.mode = mode
        self.rows = rows
    }
}

struct SiteRacking: Codable, Equatable {
    var uprights: SiteRackingSection<UprightSpec>
    var beams: SiteRackingSection<BeamSpec>
    var decks: SiteRackingSection<DeckSpec>

    static var empty: SiteRacking {
        SiteRacking(
            uprights: SiteRackingSection(),
            beams: SiteRackingSection(),
            decks: SiteRackingSection()
        )
    }

    var uprightsRecorded: Bool {
        uprights.rows.contains { $0.hasManufacturer }
    }

    var beamsRecorded: Bool {
        beams.rows.contains { $0.hasManufacturer }
    }

    var decksRecorded: Bool {
        decks.rows.contains { $0.hasManufacturer }
    }

    var isEmpty: Bool {
        !uprightsRecorded && !beamsRecorded && !decksRecorded
    }

    func canSetUprightsStandardized() -> Bool { uprights.rows.count <= 1 }
    func canSetBeamsStandardized() -> Bool { beams.rows.count <= 1 }
    func canSetDecksStandardized() -> Bool { decks.rows.count <= 1 }

    func validationMessage() -> String? {
        if uprightsRecorded && !beamsRecorded {
            return "Beams are required when Uprights are recorded."
        }
        if beamsRecorded && !uprightsRecorded {
            return "Uprights are required when Beams are recorded."
        }
        if decks.rows.contains(where: { $0.hasManufacturer && $0.type.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            return "Each deck needs a type."
        }
        return nil
    }

    func jsonData() -> Data? {
        guard !isEmpty else { return nil }
        var copy = self
        copy.uprights.rows.removeAll { !$0.hasManufacturer }
        copy.beams.rows.removeAll { !$0.hasManufacturer }
        copy.decks.rows.removeAll { !$0.hasManufacturer }
        return try? JSONEncoder().encode(copy)
    }

    static func from(jsonData: Data?) -> SiteRacking {
        guard let jsonData, !jsonData.isEmpty else { return .empty }
        return (try? JSONDecoder().decode(SiteRacking.self, from: jsonData)) ?? .empty
    }
}
