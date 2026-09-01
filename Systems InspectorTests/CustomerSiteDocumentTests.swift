//
//  CustomerSiteDocumentTests.swift
//  Systems InspectorTests
//

import CoreData
import XCTest
@testable import Systems_Inspector

final class CustomerSiteDocumentTests: XCTestCase {
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

    private func makeCustomer() -> Customer {
        let customer = Customer(context: context)
        customer.id = UUID()
        customer.name = "Acme"
        return customer
    }

    func testReplaceCapsAtFive() {
        let customer = makeCustomer()
        let files = (0..<6).map { i in
            SiteDocumentFile(id: nil, filename: "f\(i).pdf", contentType: "public.pdf", data: Data([UInt8(i)]))
        }
        customer.replaceDocuments(files, userId: UUID())
        XCTAssertEqual(customer.documentFiles().count, 5)
        XCTAssertEqual(customer.documentFiles().map(\.filename), ["f0.pdf", "f1.pdf", "f2.pdf", "f3.pdf", "f4.pdf"])
    }

    func testKeepByIdDoesNotRewriteData() {
        let userId = UUID()
        let customer = makeCustomer()
        let original = Data([1, 2, 3])
        customer.replaceDocuments([
            SiteDocumentFile(id: nil, filename: "a.jpg", contentType: "public.jpeg", data: original)
        ], userId: userId)
        let id = customer.documentFiles()[0].id
        XCTAssertNotNil(id)
        customer.replaceDocuments([
            SiteDocumentFile(id: id, filename: "a.jpg", contentType: "public.jpeg", data: Data([9, 9, 9]))
        ], userId: userId)
        XCTAssertEqual(customer.documentFiles()[0].data, original)
    }

    func testMissingIdDeletesDocument() {
        let customer = makeCustomer()
        customer.replaceDocuments([
            SiteDocumentFile(id: nil, filename: "a.pdf", contentType: "public.pdf", data: Data([1])),
            SiteDocumentFile(id: nil, filename: "b.pdf", contentType: "public.pdf", data: Data([2]))
        ], userId: UUID())
        let keep = customer.documentFiles()[0]
        customer.replaceDocuments([keep], userId: UUID())
        XCTAssertEqual(customer.documentFiles().map(\.filename), [keep.filename])
    }
}
