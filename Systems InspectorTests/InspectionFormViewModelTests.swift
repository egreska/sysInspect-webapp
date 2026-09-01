//
//  InspectionFormViewModelTests.swift
//  Systems InspectorTests
//

import CoreData
import XCTest
@testable import Systems_Inspector

final class InspectionFormViewModelTests: XCTestCase {

    var container: NSPersistentContainer!
    var context: NSManagedObjectContext!
    var sessionDefaults: SessionTestDefaults!
    var previousInspectorName: String?

    override func setUp() {
        super.setUp()
        sessionDefaults = SessionTestDefaults()
        sessionDefaults.install()
        previousInspectorName = UserDefaults.standard.string(forKey: "inspectorName")
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
        UserManager.shared.startSession(userId: UUID())
        UserDefaults.standard.set("Snap Inspector", forKey: "inspectorName")
    }

    override func tearDown() {
        sessionDefaults.uninstall()
        sessionDefaults = nil
        UserDefaults.standard.set(previousInspectorName, forKey: "inspectorName")
        context = nil
        container = nil
        super.tearDown()
    }

    private func makeCustomer(name: String = "Acme") -> Customer {
        let customer = Customer(context: context)
        customer.name = name
        return customer
    }

    private func form(location: String = "Aisle") -> InspectionItemFormState {
        InspectionItemFormState(location: location)
    }

    func testNewViewModelDoesNotCreateInspection() {
        let customer = makeCustomer()
        let viewModel = InspectionFormViewModel(customer: customer)
        XCTAssertNil(viewModel.inspection)
        XCTAssertFalse(viewModel.hasInspectionItems())
        XCTAssertEqual(customer.inspections?.count ?? 0, 0)
    }

    func testInspectionForNewItemCreatesInspectionAndStampsIdentity() {
        let customer = makeCustomer()
        let session = UserManager.shared.sessionUserId
        let viewModel = InspectionFormViewModel(customer: customer)
        let inspection = viewModel.inspectionForNewItem()
        XCTAssertNotNil(inspection.id)
        XCTAssertNotNil(inspection.date)
        XCTAssertEqual(inspection.userId, session)
        XCTAssertEqual(inspection.inspectorName, "Snap Inspector")
        XCTAssertEqual(inspection.customer, customer)
        XCTAssertFalse(viewModel.hasInspectionItems())
        XCTAssertEqual((inspection.items as? Set<InspectionItem>)?.count ?? 0, 0)
    }

    func testSecondInspectionForNewItemDoesNotRestamp() {
        let customer = makeCustomer()
        let viewModel = InspectionFormViewModel(customer: customer)
        let first = viewModel.inspectionForNewItem()
        let originalId = first.id
        let originalDate = first.date
        let originalUser = first.userId
        UserManager.shared.startSession(userId: UUID())
        UserDefaults.standard.set("Other Inspector", forKey: "inspectorName")
        let second = viewModel.inspectionForNewItem()
        XCTAssertTrue(first === second)
        XCTAssertEqual(second.id, originalId)
        XCTAssertEqual(second.date, originalDate)
        XCTAssertEqual(second.userId, originalUser)
        XCTAssertEqual(second.inspectorName, "Snap Inspector")
    }

    func testResumeDoesNotChangeInspectorNameOrNonNilUserId() {
        let customer = makeCustomer()
        let inspection = Inspection(context: context)
        inspection.id = UUID()
        inspection.date = Date(timeIntervalSince1970: 1_700_000_000)
        inspection.inspectorName = "Pat"
        inspection.userId = UUID()
        inspection.customer = customer
        let originalUser = inspection.userId
        UserManager.shared.startSession(userId: UUID())
        UserDefaults.standard.set("Other Inspector", forKey: "inspectorName")
        let viewModel = InspectionFormViewModel(existingInspection: inspection)
        XCTAssertEqual(viewModel.inspection?.inspectorName, "Pat")
        XCTAssertEqual(viewModel.inspection?.userId, originalUser)
        _ = viewModel.inspectionForNewItem()
        XCTAssertEqual(viewModel.inspection?.inspectorName, "Pat")
        XCTAssertEqual(viewModel.inspection?.userId, originalUser)
    }

    func testResumeRepairsNilUserIdOnly() {
        let inspection = Inspection(context: context)
        inspection.inspectorName = "Pat"
        let session = UUID()
        UserManager.shared.startSession(userId: session)
        let viewModel = InspectionFormViewModel(existingInspection: inspection)
        XCTAssertEqual(viewModel.inspection?.userId, session)
        XCTAssertNotNil(viewModel.inspection?.id)
        XCTAssertNotNil(viewModel.inspection?.date)
        XCTAssertEqual(viewModel.inspection?.inspectorName, "Pat")
    }

    func testAbandonIfEmptyIsNoOpWhenNeverCreated() {
        let customer = makeCustomer()
        let viewModel = InspectionFormViewModel(customer: customer)
        viewModel.abandonIfEmpty()
        XCTAssertNil(viewModel.inspection)
        XCTAssertEqual(customer.inspections?.count ?? 0, 0)
    }

    func testAbandonIfEmptyDoesNotDeleteAfterItemsExist() {
        let customer = makeCustomer()
        let viewModel = InspectionFormViewModel(customer: customer)
        let inspection = viewModel.inspectionForNewItem()
        InspectionItemIntake.create(into: inspection, form: form())
        viewModel.abandonIfEmpty()
        XCTAssertNotNil(viewModel.inspection)
        XCTAssertEqual((viewModel.inspection?.items as? Set<InspectionItem>)?.count, 1)
    }

    func testFinishWithNoItemsDoesNotCreateARow() {
        let customer = makeCustomer()
        let viewModel = InspectionFormViewModel(customer: customer)
        viewModel.finish()
        XCTAssertNil(viewModel.inspection)
        XCTAssertEqual(customer.inspections?.count ?? 0, 0)
    }

    func testResumeFinishDoesNotCreateAndLeavesIdentity() {
        let customer = makeCustomer()
        let inspection = Inspection(context: context)
        inspection.id = UUID()
        inspection.date = Date()
        inspection.inspectorName = "Pat"
        inspection.userId = UUID()
        inspection.customer = customer
        let viewModel = InspectionFormViewModel(existingInspection: inspection)
        UserDefaults.standard.set("Other Inspector", forKey: "inspectorName")
        viewModel.finish()
        XCTAssertEqual(viewModel.inspection?.inspectorName, "Pat")
        XCTAssertEqual(viewModel.inspection, inspection)
    }
}
