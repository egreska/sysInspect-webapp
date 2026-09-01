//
//  CustomerIntakeTests.swift
//  Systems InspectorTests
//

import CoreData
import XCTest
@testable import Systems_Inspector

final class CustomerIntakeTests: XCTestCase {

    var container: NSPersistentContainer!
    var context: NSManagedObjectContext!
    var sessionDefaults: SessionTestDefaults!

    override func setUp() {
        super.setUp()
        sessionDefaults = SessionTestDefaults()
        sessionDefaults.install()
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
        container.loadPersistentStores { _, error in
            loadError = error
        }
        XCTAssertNil(loadError, "In-memory store failed to load: \(String(describing: loadError))")
        context = container.viewContext
    }

    override func tearDown() {
        sessionDefaults.uninstall()
        sessionDefaults = nil
        context = nil
        container = nil
        super.tearDown()
    }

    func testCreateReturnsNilWithoutSession() {
        let form = CustomerFormState(name: "Acme")
        XCTAssertNil(CustomerIntake.create(form: form, in: context))
    }

    func testCreateStampsIdentityAndTrimsFields() {
        let userId = UUID()
        UserManager.shared.startSession(userId: userId)
        let form = CustomerFormState(
            name: "  Acme Racks  ",
            site: " Warehouse ",
            contactName: " Pat ",
            phone: "5551234",
            address: " 1 Main ",
            city: " Dallas ",
            state: " tx ",
            zipCode: " 75201 "
        )
        let customer = CustomerIntake.create(form: form, in: context)
        XCTAssertNotNil(customer)
        XCTAssertEqual(customer?.name, "Acme Racks")
        XCTAssertEqual(customer?.site, "Warehouse")
        XCTAssertEqual(customer?.contactName, "Pat")
        XCTAssertEqual(customer?.phone, "5551234")
        XCTAssertEqual(customer?.address, "1 Main")
        XCTAssertEqual(customer?.city, "Dallas")
        XCTAssertEqual(customer?.state, "tx")
        XCTAssertEqual(customer?.zipCode, "75201")
        XCTAssertEqual(customer?.userId, userId)
        XCTAssertNotNil(customer?.id)
        XCTAssertNotNil(customer?.createdDate)
    }

    func testCreateClearsEmptyOptionalFields() {
        UserManager.shared.startSession(userId: UUID())
        let form = CustomerFormState(name: "Acme", site: "  ")
        let customer = CustomerIntake.create(form: form, in: context)
        XCTAssertEqual(customer?.name, "Acme")
        XCTAssertNil(customer?.site)
    }

    func testUpdateWritesFields() {
        UserManager.shared.startSession(userId: UUID())
        let customer = Customer(context: context)
        customer.name = "Old"
        customer.userId = UserManager.shared.sessionUserId
        CustomerIntake.update(
            customer,
            form: CustomerFormState(name: " New Co ", phone: "999")
        )
        XCTAssertEqual(customer.name, "New Co")
        XCTAssertEqual(customer.phone, "999")
    }

    func testHydrateRoundTrip() {
        let customer = Customer(context: context)
        customer.name = "Acme"
        customer.site = "North"
        customer.contactName = "Pat"
        customer.phone = "555"
        customer.address = "1 Main"
        customer.city = "Dallas"
        customer.state = "TX"
        customer.zipCode = "75201"
        let form = CustomerIntake.formState(from: customer)
        XCTAssertEqual(form.name, "Acme")
        XCTAssertEqual(form.site, "North")
        XCTAssertEqual(form.contactName, "Pat")
        XCTAssertEqual(form.phone, "555")
        XCTAssertEqual(form.address, "1 Main")
        XCTAssertEqual(form.city, "Dallas")
        XCTAssertEqual(form.state, "TX")
        XCTAssertEqual(form.zipCode, "75201")
        XCTAssertTrue(form.isValid)
    }

    func testCreateHydrateUpdateSiteRackingAndDocuments() {
        let userId = UUID()
        UserManager.shared.startSession(userId: userId)
        var form = CustomerFormState(name: "Acme")
        form.siteRacking.uprights.rows = [UprightSpec(manufacturer: "Interlake", height: "16'")]
        form.siteRacking.beams.rows = [BeamSpec(manufacturer: "Interlake")]
        form.siteDocuments = [
            SiteDocumentFile(id: nil, filename: "plan.pdf", contentType: "public.pdf", data: Data([0x25, 0x50, 0x44, 0x46]))
        ]
        let customer = CustomerIntake.create(form: form, in: context)
        XCTAssertNotNil(customer?.siteRackingJSON)
        XCTAssertEqual(customer?.documentFiles().count, 1)

        var loaded = CustomerIntake.formState(from: customer!)
        XCTAssertEqual(loaded.siteRacking.uprights.rows.first?.manufacturer, "Interlake")
        XCTAssertEqual(loaded.siteDocuments.first?.filename, "plan.pdf")
        XCTAssertEqual(loaded.siteDocuments.first?.data, Data([0x25, 0x50, 0x44, 0x46]))
        let docId = loaded.siteDocuments[0].id
        XCTAssertNotNil(docId)

        loaded.name = "Acme 2"
        XCTAssertTrue(CustomerIntake.update(customer!, form: loaded))
        XCTAssertEqual(customer!.name, "Acme 2")
        XCTAssertEqual(customer!.documentFiles()[0].data, Data([0x25, 0x50, 0x44, 0x46]))
        XCTAssertEqual(customer!.documentFiles()[0].id, docId)
    }
}
