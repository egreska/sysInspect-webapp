//
//  Catalog.swift
//  Systems Inspector
//

import CoreData
import Foundation

enum CatalogKind: String {
    case manufacturer
    case deckType
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
    static let deckTypeSeed: [String] = ["wire", "particle", "bar grate", "other"]

    static func names(kind: CatalogKind, userId: UUID, in context: NSManagedObjectContext) -> [String] {
        let existing = fetch(kind: kind, userId: userId, in: context)
        if existing.isEmpty {
            let seed = kind == .manufacturer ? manufacturerSeed : deckTypeSeed
            for name in seed {
                insert(name: name, kind: kind, userId: userId, in: context)
            }
        }
        return fetch(kind: kind, userId: userId, in: context)
            .compactMap(\.name)
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
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
