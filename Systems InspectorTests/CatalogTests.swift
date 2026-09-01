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

    func testSeedIsScopedByUser() {
        let a = UUID()
        let b = UUID()
        _ = Catalog.names(kind: .deckType, userId: a, in: context)
        _ = Catalog.names(kind: .deckType, userId: b, in: context)
        let request = CatalogName.fetchRequest()
        request.predicate = NSPredicate(format: "kind == %@", "deckType")
        XCTAssertEqual(try context.count(for: request), Catalog.deckTypeSeed.count * 2)
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
