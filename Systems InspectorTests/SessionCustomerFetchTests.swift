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
}
