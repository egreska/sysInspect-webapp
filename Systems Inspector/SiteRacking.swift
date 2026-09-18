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

struct SiteInformation: Codable, Equatable {
    var numberOfBays: String?
    var numberOfBeamLevels: String?
    var beamSpacing: String?

    init(
        numberOfBays: String? = nil,
        numberOfBeamLevels: String? = nil,
        beamSpacing: String? = nil
    ) {
        self.numberOfBays = numberOfBays
        self.numberOfBeamLevels = numberOfBeamLevels
        self.beamSpacing = beamSpacing
    }

    var isRecorded: Bool {
        [numberOfBays, numberOfBeamLevels, beamSpacing].contains { SiteRacking.hasText($0) }
    }
}

struct LoadInformation: Codable, Equatable {
    var maximumWeight: String?
    var palletDimensions: String?
    var loadDimensions: String?
    var storedContents: String?

    init(
        maximumWeight: String? = nil,
        palletDimensions: String? = nil,
        loadDimensions: String? = nil,
        storedContents: String? = nil
    ) {
        self.maximumWeight = maximumWeight
        self.palletDimensions = palletDimensions
        self.loadDimensions = loadDimensions
        self.storedContents = storedContents
    }

    var isRecorded: Bool {
        [maximumWeight, palletDimensions, loadDimensions, storedContents].contains { SiteRacking.hasText($0) }
    }
}

enum RackingConstruction: String, Codable, Equatable {
    case structural
    case rollFormed
}

struct UprightSpec: Codable, Equatable, SiteRackingRow {
    var manufacturer: String
    var type: String?
    var height: String?
    var depth: String?
    var capacity: String?
    var construction: RackingConstruction

    init(
        manufacturer: String,
        type: String? = nil,
        height: String? = nil,
        depth: String? = nil,
        capacity: String? = nil,
        construction: RackingConstruction = .structural
    ) {
        self.manufacturer = manufacturer
        self.type = type
        self.height = height
        self.depth = depth
        self.capacity = capacity
        self.construction = construction
    }

    enum CodingKeys: String, CodingKey {
        case manufacturer, type, height, depth, capacity, construction
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        manufacturer = try container.decode(String.self, forKey: .manufacturer)
        type = try container.decodeIfPresent(String.self, forKey: .type)
        height = try container.decodeIfPresent(String.self, forKey: .height)
        depth = try container.decodeIfPresent(String.self, forKey: .depth)
        capacity = try container.decodeIfPresent(String.self, forKey: .capacity)
        construction = try container.decodeIfPresent(RackingConstruction.self, forKey: .construction) ?? .structural
    }
}

struct BeamSpec: Codable, Equatable, SiteRackingRow {
    var manufacturer: String
    var type: String?
    var length: String?
    var face: String?
    var stepDimensions: String?
    var capacity: String?

    init(
        manufacturer: String,
        type: String? = nil,
        length: String? = nil,
        face: String? = nil,
        stepDimensions: String? = nil,
        capacity: String? = nil
    ) {
        self.manufacturer = manufacturer
        self.type = type
        self.length = length
        self.face = face
        self.stepDimensions = stepDimensions
        self.capacity = capacity
    }

    enum CodingKeys: String, CodingKey {
        case manufacturer, type, length, face, stepDimensions, capacity
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        manufacturer = try container.decode(String.self, forKey: .manufacturer)
        type = try container.decodeIfPresent(String.self, forKey: .type)
        length = try container.decodeIfPresent(String.self, forKey: .length)
        face = try container.decodeIfPresent(String.self, forKey: .face)
        stepDimensions = try container.decodeIfPresent(String.self, forKey: .stepDimensions)
        capacity = try container.decodeIfPresent(String.self, forKey: .capacity)
    }
}

struct DeckSpec: Codable, Equatable, SiteRackingRow {
    var manufacturer: String
    var capacity: String?
    var type: String
    var udl: Bool
    var numberOfDecks: String?

    init(
        manufacturer: String,
        capacity: String? = nil,
        type: String,
        udl: Bool = false,
        numberOfDecks: String? = nil
    ) {
        self.manufacturer = manufacturer
        self.capacity = capacity
        self.type = type
        self.udl = udl
        self.numberOfDecks = numberOfDecks
    }

    enum CodingKeys: String, CodingKey {
        case manufacturer, capacity, type, udl, numberOfDecks
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        manufacturer = try container.decode(String.self, forKey: .manufacturer)
        capacity = try container.decodeIfPresent(String.self, forKey: .capacity)
        type = try container.decodeIfPresent(String.self, forKey: .type) ?? ""
        udl = try container.decodeIfPresent(Bool.self, forKey: .udl) ?? false
        numberOfDecks = try container.decodeIfPresent(String.self, forKey: .numberOfDecks)
    }
}

struct CrossBarSpec: Codable, Equatable, SiteRackingRow {
    var manufacturer: String
    var size: String?

    init(manufacturer: String, size: String? = nil) {
        self.manufacturer = manufacturer
        self.size = size
    }
}

struct SafetyClipsSpec: Codable, Equatable {
    var present: Bool
    var neededCount: String?

    init(present: Bool = false, neededCount: String? = nil) {
        self.present = present
        self.neededCount = neededCount
    }
}

struct AnchorSpec: Codable, Equatable, SiteRackingRow {
    var manufacturer: String
    var size: String?

    init(manufacturer: String, size: String? = nil) {
        self.manufacturer = manufacturer
        self.size = size
    }
}

struct RowSpacerSpec: Codable, Equatable, SiteRackingRow {
    var manufacturer: String
    var length: String?
    var width: String?

    init(manufacturer: String, length: String? = nil, width: String? = nil) {
        self.manufacturer = manufacturer
        self.length = length
        self.width = width
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
    var siteInformation: SiteInformation
    var loadInformation: LoadInformation
    var uprights: SiteRackingSection<UprightSpec>
    var beams: SiteRackingSection<BeamSpec>
    var decks: SiteRackingSection<DeckSpec>
    var crossBars: SiteRackingSection<CrossBarSpec>
    var safetyClips: SafetyClipsSpec
    var anchors: SiteRackingSection<AnchorSpec>
    var rowSpacers: SiteRackingSection<RowSpacerSpec>

    init(
        siteInformation: SiteInformation = SiteInformation(),
        loadInformation: LoadInformation = LoadInformation(),
        uprights: SiteRackingSection<UprightSpec> = SiteRackingSection(),
        beams: SiteRackingSection<BeamSpec> = SiteRackingSection(),
        decks: SiteRackingSection<DeckSpec> = SiteRackingSection(),
        crossBars: SiteRackingSection<CrossBarSpec> = SiteRackingSection(),
        safetyClips: SafetyClipsSpec = SafetyClipsSpec(),
        anchors: SiteRackingSection<AnchorSpec> = SiteRackingSection(),
        rowSpacers: SiteRackingSection<RowSpacerSpec> = SiteRackingSection()
    ) {
        self.siteInformation = siteInformation
        self.loadInformation = loadInformation
        self.uprights = uprights
        self.beams = beams
        self.decks = decks
        self.crossBars = crossBars
        self.safetyClips = safetyClips
        self.anchors = anchors
        self.rowSpacers = rowSpacers
    }

    static var empty: SiteRacking { SiteRacking() }

    var uprightsRecorded: Bool {
        uprights.rows.contains { $0.hasManufacturer }
    }

    var beamsRecorded: Bool {
        beams.rows.contains { $0.hasManufacturer }
    }

    var decksRecorded: Bool {
        decks.rows.contains { $0.hasManufacturer }
    }

    var crossBarsRecorded: Bool {
        crossBars.rows.contains { $0.hasManufacturer }
    }

    var anchorsRecorded: Bool {
        anchors.rows.contains { $0.hasManufacturer }
    }

    var rowSpacersRecorded: Bool {
        rowSpacers.rows.contains { $0.hasManufacturer }
    }

    var isEmpty: Bool {
        !siteInformation.isRecorded
            && !loadInformation.isRecorded
            && !uprightsRecorded
            && !beamsRecorded
            && !decksRecorded
            && !crossBarsRecorded
            && !safetyClips.present
            && !anchorsRecorded
            && !rowSpacersRecorded
    }

    func canSetUprightsStandardized() -> Bool { uprights.rows.count <= 1 }
    func canSetBeamsStandardized() -> Bool { beams.rows.count <= 1 }
    func canSetDecksStandardized() -> Bool { decks.rows.count <= 1 }
    func canSetCrossBarsStandardized() -> Bool { crossBars.rows.count <= 1 }
    func canSetAnchorsStandardized() -> Bool { anchors.rows.count <= 1 }
    func canSetRowSpacersStandardized() -> Bool { rowSpacers.rows.count <= 1 }

    func validationMessage() -> String? {
        if uprightsRecorded && !beamsRecorded {
            return "Beams are required when Upright Frames are recorded."
        }
        if beamsRecorded && !uprightsRecorded {
            return "Upright Frames are required when Beams are recorded."
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
        copy.crossBars.rows.removeAll { !$0.hasManufacturer }
        copy.anchors.rows.removeAll { !$0.hasManufacturer }
        copy.rowSpacers.rows.removeAll { !$0.hasManufacturer }
        if !copy.safetyClips.present {
            copy.safetyClips.neededCount = nil
        }
        return try? JSONEncoder().encode(copy)
    }

    static func from(jsonData: Data?) -> SiteRacking {
        guard let jsonData, !jsonData.isEmpty else { return .empty }
        return (try? JSONDecoder().decode(SiteRacking.self, from: jsonData)) ?? .empty
    }

    fileprivate static func hasText(_ value: String?) -> Bool {
        guard let value else { return false }
        return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

extension SiteRacking {
    enum CodingKeys: String, CodingKey {
        case siteInformation, loadInformation, uprights, beams, decks, crossBars, safetyClips, anchors, rowSpacers
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        siteInformation = try container.decodeIfPresent(SiteInformation.self, forKey: .siteInformation) ?? SiteInformation()
        loadInformation = try container.decodeIfPresent(LoadInformation.self, forKey: .loadInformation) ?? LoadInformation()
        uprights = try container.decodeIfPresent(SiteRackingSection<UprightSpec>.self, forKey: .uprights) ?? SiteRackingSection()
        beams = try container.decodeIfPresent(SiteRackingSection<BeamSpec>.self, forKey: .beams) ?? SiteRackingSection()
        decks = try container.decodeIfPresent(SiteRackingSection<DeckSpec>.self, forKey: .decks) ?? SiteRackingSection()
        crossBars = try container.decodeIfPresent(SiteRackingSection<CrossBarSpec>.self, forKey: .crossBars) ?? SiteRackingSection()
        safetyClips = try container.decodeIfPresent(SafetyClipsSpec.self, forKey: .safetyClips) ?? SafetyClipsSpec()
        anchors = try container.decodeIfPresent(SiteRackingSection<AnchorSpec>.self, forKey: .anchors) ?? SiteRackingSection()
        rowSpacers = try container.decodeIfPresent(SiteRackingSection<RowSpacerSpec>.self, forKey: .rowSpacers) ?? SiteRackingSection()
    }
}
