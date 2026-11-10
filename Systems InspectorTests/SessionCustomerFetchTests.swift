import CoreData
import XCTest
@testable import Systems_Inspector

final class SessionCustomerFetchTests: XCTestCase {
    private var container: NSPersistentContainer!
    private var context: NSManagedObjectContext!

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

    func testPageAndSearchLeaveOutAnotherUsersCustomer() throws {
        let session = UUID()
        let other = UUID()
        let mine = Customer(context: context)
        mine.name = "Acme"
        mine.city = "Dallas"
        mine.userId = session
        let theirs = Customer(context: context)
        theirs.name = "Acme"
        theirs.city = "Dallas"
        theirs.userId = other
        try context.save()

        let page = try fetchSessionCustomers(.page(offset: 0), userId: session, in: context)
        XCTAssertEqual(page.customers.map(\.objectID), [mine.objectID])
        XCTAssertEqual(page.total, 1)

        let search = try fetchSessionCustomers(.search("Dallas"), userId: session, in: context)
        XCTAssertEqual(search.customers.map(\.objectID), [mine.objectID])
        XCTAssertNil(search.total)
    }

    func testInspectionsAreNewestFirstAndLeaveOutOtherStamps() throws {
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
        let other = Inspection(context: context)
        other.userId = UUID()
        other.customer = customer
        other.date = Date(timeIntervalSince1970: 30)
        let unstamped = Inspection(context: context)
        unstamped.customer = customer
        unstamped.date = Date(timeIntervalSince1970: 40)
        try context.save()

        let fetched = try fetchSessionInspections(for: customer, userId: session, in: context)
        XCTAssertEqual(fetched.map(\.objectID), [newer.objectID, older.objectID])
        XCTAssertEqual(try sessionInspectionCount(for: customer, userId: session, in: context), 2)
    }

    func testInspectionItemsLeaveOutOtherStamps() throws {
        let session = UUID()
        let inspection = Inspection(context: context)
        inspection.userId = session
        let mine = InspectionItem(context: context)
        mine.userId = session
        mine.inspection = inspection
        mine.location = "Z"
        let other = InspectionItem(context: context)
        other.userId = UUID()
        other.inspection = inspection
        other.location = "A"
        let unstamped = InspectionItem(context: context)
        unstamped.inspection = inspection
        unstamped.location = "M"
        try context.save()

        let fetched = try fetchSessionInspectionItems(for: inspection, userId: session, in: context)
        XCTAssertEqual(Set(fetched.map(\.objectID)), [mine.objectID])
        XCTAssertEqual(try sessionInspectionItemCount(for: inspection, userId: session, in: context), 1)
    }

    func testCustomerIdResolvesOnlyForThisStamp() throws {
        let session = UUID()
        let mineId = UUID()
        let theirsId = UUID()
        let blankId = UUID()
        let mine = Customer(context: context)
        mine.id = mineId
        mine.userId = session
        let theirs = Customer(context: context)
        theirs.id = theirsId
        theirs.userId = UUID()
        let blank = Customer(context: context)
        blank.id = blankId
        try context.save()

        XCTAssertEqual(try fetchSessionCustomer(id: mineId, userId: session, in: context)?.objectID, mine.objectID)
        XCTAssertNil(try fetchSessionCustomer(id: theirsId, userId: session, in: context))
        XCTAssertNil(try fetchSessionCustomer(id: blankId, userId: session, in: context))
        XCTAssertNil(try fetchSessionCustomer(id: UUID(), userId: session, in: context))
    }
}
