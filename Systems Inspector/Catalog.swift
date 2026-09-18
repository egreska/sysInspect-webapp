//
//  Catalog.swift
//  Systems Inspector
//

import CoreData
import Foundation

enum CatalogKind: String {
    case manufacturer
    case deckType
    case wireDeckManufacturer
}

enum CatalogAddResult: Equatable {
    case added(String)
    case duplicate
    case blank
}

enum Catalog {
    static let manufacturerSeed: [String] = [
        "Interlake", "Ridg-U-Rak", "Mecalux", "Steel King",
        "UNARCO", "Hannibal", "Speedrack", "Frazier", "Teardrop (generic)"
    ]
    static let deckTypeSeed: [String] = [
        "Upturned WF",
        "Inside WF",
        "Flat Flush",
        "Inverted Flare",
        "Inverted U-Channel",
        "Standard U-Channel",
        "Flared Channel",
        "Welded Wire Decking"
    ]
    static let wireDeckManufacturerSeed: [String] = [
        "Nashville Wire",
        "J&L Wire",
        "ITC",
        "Worldwide",
        "Little Giant (Brennan)",
        "Hallowell",
        "Husky",
        "Interlake Mecalux",
        "Steel King",
        "Ridg-U-Rak"
    ]
    private static let retiredDeckTypeSeed: [String] = ["wire", "particle", "bar grate", "other"]

    static func names(kind: CatalogKind, userId: UUID, in context: NSManagedObjectContext) -> [String] {
        switch kind {
        case .deckType:
            ensureDeckTypes(userId: userId, in: context)
        case .wireDeckManufacturer:
            ensureSeeded(kind: .wireDeckManufacturer, seed: wireDeckManufacturerSeed, userId: userId, in: context)
        case .manufacturer:
            if fetch(kind: kind, userId: userId, in: context).isEmpty {
                for name in manufacturerSeed {
                    insert(name: name, kind: kind, userId: userId, in: context)
                }
            }
        }
        let fetched = fetch(kind: kind, userId: userId, in: context).compactMap(\.name)
        if kind == .wireDeckManufacturer {
            return ordered(fetched, seed: wireDeckManufacturerSeed)
        }
        return fetched.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    static func add(
        name: String,
        kind: CatalogKind,
        userId: UUID,
        in context: NSManagedObjectContext
    ) -> CatalogAddResult {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .blank }
        let existing = fetch(kind: kind, userId: userId, in: context)
        if existing.contains(where: { ($0.name ?? "").caseInsensitiveCompare(trimmed) == .orderedSame }) {
            return .duplicate
        }
        insert(name: trimmed, kind: kind, userId: userId, in: context)
        return .added(trimmed)
    }

    private static func ensureDeckTypes(userId: UUID, in context: NSManagedObjectContext) {
        let retired = Set(retiredDeckTypeSeed.map { $0.lowercased() })
        for row in fetch(kind: .deckType, userId: userId, in: context) {
            if retired.contains((row.name ?? "").lowercased()) {
                context.delete(row)
            }
        }
        context.processPendingChanges()
        ensureSeeded(kind: .deckType, seed: deckTypeSeed, userId: userId, in: context)
    }

    private static func ensureSeeded(
        kind: CatalogKind,
        seed: [String],
        userId: UUID,
        in context: NSManagedObjectContext
    ) {
        let remaining = fetch(kind: kind, userId: userId, in: context)
        let have = Set(remaining.compactMap(\.name).map { $0.lowercased() })
        for name in seed where !have.contains(name.lowercased()) {
            insert(name: name, kind: kind, userId: userId, in: context)
        }
    }

    private static func ordered(_ names: [String], seed: [String]) -> [String] {
        let byLower = Dictionary(names.map { ($0.lowercased(), $0) }, uniquingKeysWith: { first, _ in first })
        var used = Set<String>()
        var result: [String] = []
        for seedName in seed {
            let key = seedName.lowercased()
            if let actual = byLower[key] {
                result.append(actual)
                used.insert(key)
            }
        }
        let extras = names
            .filter { !used.contains($0.lowercased()) }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        return result + extras
    }

    private static func fetch(
        kind: CatalogKind,
        userId: UUID,
        in context: NSManagedObjectContext
    ) -> [CatalogName] {
        let request = CatalogName.fetchRequest()
        request.predicate = NSPredicate(format: "userId == %@ AND kind == %@", userId as CVarArg, kind.rawValue)
        return (try? context.fetch(request)) ?? []
    }

    private static func insert(
        name: String,
        kind: CatalogKind,
        userId: UUID,
        in context: NSManagedObjectContext
    ) {
        let row = CatalogName(context: context)
        row.id = UUID()
        row.kind = kind.rawValue
        row.name = name
        row.userId = userId
    }
}
