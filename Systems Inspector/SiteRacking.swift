//
//  SiteRacking.swift
//  Systems Inspector
//

import Foundation

enum SiteRackingMode: String, Codable, Equatable {
    case standardized
    case mixed
}

protocol SiteRackingRow: Codable, Equatable {
    var manufacturer: String { get }
    static var blank: Self { get }
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

extension UprightSpec {
    static var blank: UprightSpec { UprightSpec(manufacturer: "") }
}

extension BeamSpec {
    static var blank: BeamSpec { BeamSpec(manufacturer: "") }
}

extension DeckSpec {
    static var blank: DeckSpec { DeckSpec(manufacturer: "", type: "") }
}

extension CrossBarSpec {
    static var blank: CrossBarSpec { CrossBarSpec(manufacturer: "") }
}

extension AnchorSpec {
    static var blank: AnchorSpec { AnchorSpec(manufacturer: "") }
}

extension RowSpacerSpec {
    static var blank: RowSpacerSpec { RowSpacerSpec(manufacturer: "") }
}

struct SiteRackingSection<Row: SiteRackingRow>: Codable, Equatable {
    private(set) var mode: SiteRackingMode
    private(set) var rows: [Row]

    init(mode: SiteRackingMode = .standardized, rows: [Row] = []) {
        let recorded = rows.filter(\.hasManufacturer)
        self.mode = (mode == .standardized && recorded.count > 1) ? .mixed : mode
        self.rows = recorded
    }

    var allowsStandardized: Bool {
        rows.filter(\.hasManufacturer).count < 2
    }

    mutating func setMode(_ mode: SiteRackingMode) {
        if mode == .mixed {
            self.mode = .mixed
            return
        }
        guard allowsStandardized else { return }
        rows.removeAll { !$0.hasManufacturer }
        self.mode = .standardized
    }

    @discardableResult
    mutating func appendBlank() -> Bool {
        guard mode == .mixed else { return false }
        rows.append(Row.blank)
        return true
    }

    mutating func seedBlankIfEmpty() {
        guard rows.isEmpty else { return }
        rows.append(Row.blank)
    }

    fileprivate func droppingNamelessSpecs() -> SiteRackingSection<Row> {
        var copy = self
        copy.rows.removeAll { !$0.hasManufacturer }
        return copy
    }

    subscript(index: Int) -> Row {
        get { rows[index] }
        set { rows[index] = newValue }
    }

    private enum CodingKeys: String, CodingKey {
        case mode, rows
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let mode = try container.decodeIfPresent(SiteRackingMode.self, forKey: .mode) ?? .standardized
        let rows = try container.decodeIfPresent([Row].self, forKey: .rows) ?? []
        self.init(mode: mode, rows: rows)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(mode, forKey: .mode)
        try container.encode(rows, forKey: .rows)
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
        copy.uprights = copy.uprights.droppingNamelessSpecs()
        copy.beams = copy.beams.droppingNamelessSpecs()
        copy.decks = copy.decks.droppingNamelessSpecs()
        copy.crossBars = copy.crossBars.droppingNamelessSpecs()
        copy.anchors = copy.anchors.droppingNamelessSpecs()
        copy.rowSpacers = copy.rowSpacers.droppingNamelessSpecs()
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

    private static let cardSummaryEmpty = "Not filled"

    var siteInformationSummary: String {
        var parts: [String] = []
        if let bays = trimmed(siteInformation.numberOfBays) {
            parts.append("\(bays) bays")
        }
        if let levels = trimmed(siteInformation.numberOfBeamLevels) {
            parts.append("\(levels) levels")
        }
        if let spacing = trimmed(siteInformation.beamSpacing) {
            parts.append("\(spacing) spacing")
        }
        return parts.isEmpty ? Self.cardSummaryEmpty : parts.joined(separator: " · ")
    }

    var loadInformationSummary: String {
        let parts = [
            trimmed(loadInformation.storedContents),
            trimmed(loadInformation.maximumWeight),
            trimmed(loadInformation.palletDimensions),
            trimmed(loadInformation.loadDimensions)
        ].compactMap { $0 }
        return parts.isEmpty ? Self.cardSummaryEmpty : parts.joined(separator: " · ")
    }

    var uprightsSummary: String { Self.manufacturerSummary(uprights.rows) }
    var beamsSummary: String { Self.manufacturerSummary(beams.rows) }
    var decksSummary: String { Self.manufacturerSummary(decks.rows) }
    var crossBarsSummary: String { Self.manufacturerSummary(crossBars.rows) }
    var anchorsSummary: String { Self.manufacturerSummary(anchors.rows) }
    var rowSpacersSummary: String { Self.manufacturerSummary(rowSpacers.rows) }

    var safetyClipsSummary: String {
        guard safetyClips.present else { return "Not present" }
        if let needed = trimmed(safetyClips.neededCount) {
            return "Present · \(needed) needed"
        }
        return "Present"
    }

    static func documentsSummary(count: Int) -> String {
        if count <= 0 { return "No documents" }
        if count == 1 { return "1 document" }
        return "\(count) documents"
    }

    private static func manufacturerSummary<Row: SiteRackingRow>(_ rows: [Row]) -> String {
        let named = rows.compactMap { trimmed($0.manufacturer) }
        if named.isEmpty { return cardSummaryEmpty }
        if named.count == 1 { return named[0] }
        return "Mixed · \(named.count) manufacturers"
    }

    private static func trimmed(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func trimmed(_ value: String?) -> String? {
        Self.trimmed(value)
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
