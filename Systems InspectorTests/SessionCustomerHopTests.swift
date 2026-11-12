//
//  SessionCustomerHopTests.swift
//  Systems InspectorTests
//

import CoreData
import XCTest
@testable import Systems_Inspector

@MainActor
final class SessionCustomerHopTests: XCTestCase {
    private var container: NSPersistentContainer!
    private var context: NSManagedObjectContext!

    override func setUp() async throws {
        try await super.setUp()
        container = try makeContainer(load: true)
        context = container.viewContext
    }

    override func tearDown() async throws {
        context = nil
        container = nil
        try await super.tearDown()
    }

    func testPageIndexReturnsThatPageOnTheViewContext() async throws {
        let session = UUID()
        let other = UUID()
        for index in 0..<(sessionCustomerPageSize + 1) {
            let customer = Customer(context: context)
            customer.name = String(format: "C%02d", index)
            customer.userId = session
        }
        let outsider = Customer(context: context)
        outsider.name = "C00"
        outsider.userId = other
        try context.save()

        let first = try await sessionCustomerPage(0, userId: session, in: context)
        XCTAssertEqual(first.total, sessionCustomerPageSize + 1)
        XCTAssertEqual(first.customers.count, sessionCustomerPageSize)
        XCTAssertEqual(first.customers.map(\.name), (0..<sessionCustomerPageSize).map { String(format: "C%02d", $0) })
        XCTAssertTrue(first.customers.allSatisfy { $0.managedObjectContext === context })

        let second = try await sessionCustomerPage(1, userId: session, in: context)
        XCTAssertEqual(second.customers.map(\.name), ["C\(sessionCustomerPageSize)"])
        XCTAssertEqual(second.total, sessionCustomerPageSize + 1)
    }

    func testInspectionsComeBackOnTheViewContext() async throws {
        let session = UUID()
        let customer = Customer(context: context)
        customer.userId = session
        let older = Inspection(context: context)
        older.userId = session
        older.customer = customer
        older.date = Date(timeIntervalSince1970: 10)
        let newer = Inspection(context: context)
        newer.userId = session
        newer.customer = customer
        newer.date = Date(timeIntervalSince1970: 20)
        try context.save()

        let fetched = try await sessionInspections(for: customer, userId: session, in: context)
        XCTAssertEqual(fetched.map(\.objectID), [newer.objectID, older.objectID])
        XCTAssertTrue(fetched.allSatisfy { $0.managedObjectContext === context })
    }

    func testItemsComeBackOnTheViewContextUnsorted() async throws {
        let session = UUID()
        let inspection = Inspection(context: context)
        inspection.userId = session
        let sequences: [Int32] = [2, 0, 1]
        for sequence in sequences {
            let item = InspectionItem(context: context)
            item.userId = session
            item.inspection = inspection
            item.sequenceNumber = sequence
        }
        try context.save()

        let hopped = try await sessionInspectionItems(for: inspection, userId: session, in: context)
        let direct = try fetchSessionInspectionItems(for: inspection, userId: session, in: context)
        XCTAssertEqual(hopped.map(\.sequenceNumber), direct.map(\.sequenceNumber))
        XCTAssertTrue(hopped.allSatisfy { $0.managedObjectContext === context })
        let recorded = RecordedOrder.sorted(direct) { $0.sequenceNumber }.map(\.sequenceNumber)
        if recorded != direct.map(\.sequenceNumber) {
            XCTAssertNotEqual(hopped.map(\.sequenceNumber), recorded)
        }
    }

    func testMissingStoreThrows() async throws {
        let unloaded = try makeContainer(load: false)
        do {
            _ = try await sessionCustomerPage(0, userId: UUID(), in: unloaded.viewContext)
            XCTFail("Expected the missing store to throw")
        } catch SessionReadHopError.storeUnavailable {
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    func testUnresolvedCustomerThrows() async throws {
        let session = UUID()
        let customer = Customer(context: context)
        customer.userId = session
        try context.save()
        context.delete(customer)
        try context.save()

        do {
            _ = try await sessionInspections(for: customer, userId: session, in: context)
            XCTFail("Expected a deleted customer to throw")
        } catch SessionReadHopError.unresolved {
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    private func makeContainer(load: Bool) throws -> NSPersistentContainer {
        guard let model = NSManagedObjectModel.mergedModel(from: [Bundle(for: CoreDataManager.self)]) else {
            throw NSError(domain: "SessionCustomerHopTests", code: 1)
        }
        let container = NSPersistentContainer(name: "Systems_Inspector", managedObjectModel: model)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        description.shouldAddStoreAsynchronously = false
        container.persistentStoreDescriptions = [description]
        guard load else { return container }
        var loadError: Error?
        container.loadPersistentStores { _, error in loadError = error }
        if let loadError { throw loadError }
        return container
    }
}
