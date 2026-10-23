import CoreData
import XCTest
@testable import Systems_Inspector

final class DeleteAccountTests: XCTestCase {
    private var container: NSPersistentContainer!
    private var context: NSManagedObjectContext!
    private var isolated: SessionTestDefaults!

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
        isolated = SessionTestDefaults()
        isolated.install()
    }

    override func tearDown() {
        isolated?.uninstall()
        isolated = nil
        context = nil
        container = nil
        super.tearDown()
    }

    func testLocalWipeEmptiesTheStoreAndKeepsSessionReady() throws {
        for name in deleteAccountEntityNames {
            _ = NSEntityDescription.insertNewObject(forEntityName: name, into: context)
        }
        try context.save()

        let email = "Delete@Example.com"
        isolated.defaults.set("kept", forKey: "securityQuestion_\(email.lowercased())")
        isolated.defaults.set("kept", forKey: "securityAnswer_\(email.lowercased())")
        for key in deleteAccountProfileKeys {
            isolated.defaults.set("kept", forKey: key)
        }
        var cache = AccessCodeCache(defaults: isolated.defaults)
        cache.save(CachedEntitlement(code: "abc", userRecordName: "pat", sessionReady: true))
        let userId = UUID()
        UserManager.shared.startSession(userId: userId)

        XCTAssertTrue(deleteAccountRecords(in: context))
        clearDeleteAccountProfile(email: email, defaults: isolated.defaults)
        UserManager.shared.wipeSession()

        for name in deleteAccountEntityNames {
            let request = NSFetchRequest<NSManagedObject>(entityName: name)
            XCTAssertEqual(try context.count(for: request), 0, name)
        }
        XCTAssertNil(isolated.defaults.string(forKey: "securityQuestion_\(email.lowercased())"))
        XCTAssertNil(isolated.defaults.string(forKey: "securityAnswer_\(email.lowercased())"))
        for key in deleteAccountProfileKeys {
            XCTAssertNil(isolated.defaults.string(forKey: key), key)
        }
        XCTAssertNil(UserManager.shared.lastUserId)
        XCTAssertNil(UserManager.shared.sessionUserId)
        XCTAssertEqual(cache.load()?.sessionReady, true)
    }
}
