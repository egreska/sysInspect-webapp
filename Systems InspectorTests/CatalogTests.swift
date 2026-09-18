//
//  CatalogTests.swift
//  Systems InspectorTests
//

import CoreData
import XCTest
@testable import Systems_Inspector

final class CatalogTests: XCTestCase {
    var container: NSPersistentContainer!
    var context: NSManagedObjectContext!

    override func setUp() {
        super.setUp()
        guard let model = NSManagedObjectModel.mergedModel(from: [Bundle(for: CoreDataManager.self)]) else {
            XCTFail("Missing Core Data model")
            return
        }
        container = NSPersistentContainer(name: "Systems_Inspector", managedObjectModel: model)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        description.shouldAddStoreAsynchronously = false
        container.persistentStoreDescriptions = [description]
        var loadError: Error?
        container.loadPersistentStores { _, error in loadError = error }
        XCTAssertNil(loadError)
        context = container.viewContext
    }

    override func tearDown() {
        context = nil
        container = nil
        super.tearDown()
    }

    func testModelIncludesCatalogNameAndSiteDocument() {
        XCTAssertNotNil(container.managedObjectModel.entitiesByName["CatalogName"])
        XCTAssertNotNil(container.managedObjectModel.entitiesByName["SiteDocument"])
        let customer = Customer(context: context)
        customer.siteRackingJSON = Data("{}".utf8)
        XCTAssertEqual(customer.siteRackingJSON, Data("{}".utf8))
        let doc = SiteDocument(context: context)
        doc.id = UUID()
        doc.customer = customer
        XCTAssertEqual(customer.siteDocuments?.count, 1)
    }

    func testFirstFetchSeedsManufacturers() {
        let userId = UUID()
        let names = Catalog.names(kind: .manufacturer, userId: userId, in: context)
        XCTAssertEqual(
            names,
            Catalog.manufacturerSeed.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        )
        _ = Catalog.names(kind: .manufacturer, userId: userId, in: context)
        let request = CatalogName.fetchRequest()
        request.predicate = NSPredicate(format: "userId == %@ AND kind == %@", userId as CVarArg, "manufacturer")
        XCTAssertEqual(try context.count(for: request), Catalog.manufacturerSeed.count)
    }

    func testFirstFetchSeedsDeckTypes() {
        let userId = UUID()
        let names = Catalog.names(kind: .deckType, userId: userId, in: context)
        XCTAssertEqual(
            names,
            Catalog.deckTypeSeed.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        )
        XCTAssertFalse(names.contains("wire"))
        XCTAssertFalse(names.contains("particle"))
        XCTAssertFalse(names.contains("bar grate"))
        XCTAssertFalse(names.contains("other"))
    }

    func testRetiredDeckTypeSeedsAreReplacedAndCustomNamesKept() {
        let userId = UUID()
        for name in ["wire", "particle", "bar grate", "other", "Custom Deck"] {
            XCTAssertEqual(Catalog.add(name: name, kind: .deckType, userId: userId, in: context), .added(name))
        }
        let names = Catalog.names(kind: .deckType, userId: userId, in: context)
        XCTAssertFalse(names.contains("wire"))
        XCTAssertFalse(names.contains("particle"))
        XCTAssertFalse(names.contains("bar grate"))
        XCTAssertFalse(names.contains("other"))
        XCTAssertTrue(names.contains("Custom Deck"))
        XCTAssertTrue(names.contains("Welded Wire Decking"))
        XCTAssertTrue(names.contains("Upturned WF"))
    }

    func testSeedIsScopedByUser() {
        let a = UUID()
        let b = UUID()
        _ = Catalog.names(kind: .deckType, userId: a, in: context)
        _ = Catalog.names(kind: .deckType, userId: b, in: context)
        let request = CatalogName.fetchRequest()
        request.predicate = NSPredicate(format: "kind == %@", "deckType")
        XCTAssertEqual(try context.count(for: request), Catalog.deckTypeSeed.count * 2)
    }

    func testFirstFetchSeedsWireDeckManufacturersInListedOrder() {
        let userId = UUID()
        let names = Catalog.names(kind: .wireDeckManufacturer, userId: userId, in: context)
        XCTAssertEqual(names, Catalog.wireDeckManufacturerSeed)
        XCTAssertEqual(names.first, "Nashville Wire")
        XCTAssertEqual(names.last, "Ridg-U-Rak")
        XCTAssertFalse(names.contains("UNARCO"))
    }

    func testWireDeckManufacturerCatalogIsSeparateFromManufacturer() {
        let userId = UUID()
        let global = Catalog.names(kind: .manufacturer, userId: userId, in: context)
        let wireDeck = Catalog.names(kind: .wireDeckManufacturer, userId: userId, in: context)
        XCTAssertTrue(global.contains("UNARCO"))
        XCTAssertFalse(global.contains("Nashville Wire"))
        XCTAssertTrue(wireDeck.contains("Nashville Wire"))
        XCTAssertFalse(wireDeck.contains("UNARCO"))
    }

    func testAddedWireDeckManufacturerStaysAfterSeedNames() {
        let userId = UUID()
        _ = Catalog.names(kind: .wireDeckManufacturer, userId: userId, in: context)
        XCTAssertEqual(
            Catalog.add(name: "Custom Wire", kind: .wireDeckManufacturer, userId: userId, in: context),
            .added("Custom Wire")
        )
        let names = Catalog.names(kind: .wireDeckManufacturer, userId: userId, in: context)
        XCTAssertEqual(Array(names.prefix(Catalog.wireDeckManufacturerSeed.count)), Catalog.wireDeckManufacturerSeed)
        XCTAssertEqual(names.last, "Custom Wire")
    }

    func testAddDeDupesCaseInsensitive() {
        let userId = UUID()
        _ = Catalog.names(kind: .manufacturer, userId: userId, in: context)
        XCTAssertEqual(Catalog.add(name: "  interlake  ", kind: .manufacturer, userId: userId, in: context), .duplicate)
        XCTAssertEqual(Catalog.add(name: "   ", kind: .manufacturer, userId: userId, in: context), .blank)
        XCTAssertEqual(Catalog.add(name: " CustomCo ", kind: .manufacturer, userId: userId, in: context), .added("CustomCo"))
        XCTAssertTrue(Catalog.names(kind: .manufacturer, userId: userId, in: context).contains("CustomCo"))
    }
}
