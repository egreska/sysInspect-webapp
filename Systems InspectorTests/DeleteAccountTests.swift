import CoreData
import UIKit
import XCTest
@testable import Systems_Inspector

@MainActor
final class DeleteAccountTests: XCTestCase {
    private var container: NSPersistentContainer!
    private var context: NSManagedObjectContext!
    private var isolated: SessionTestDefaults!
    private var cloud: DeleteAccountCloudFake!
    private var module: DeleteAccount!
    private var photoURL: URL!
    private var cacheMarker: URL!

    override func setUp() async throws {
        try await super.setUp()
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
        cloud = DeleteAccountCloudFake()
        module = DeleteAccount(
            cloud: cloud,
            context: { [unowned self] in self.context },
            defaults: isolated.defaults,
            storeLoaded: { true }
        )
        photoURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("delete-account-\(UUID().uuidString).jpg")
        cacheMarker = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ImageCache", isDirectory: true)
            .appendingPathComponent("delete-account-\(UUID().uuidString)")
    }

    override func tearDown() async throws {
        if let photoURL {
            try? FileManager.default.removeItem(at: photoURL)
        }
        if let cacheMarker {
            try? FileManager.default.removeItem(at: cacheMarker)
        }
        isolated?.uninstall()
        isolated = nil
        module = nil
        cloud = nil
        context = nil
        container = nil
        photoURL = nil
        cacheMarker = nil
        try await super.tearDown()
    }

    func testSignedOutInspectorDoesNotWipe() async throws {
        try seedAccount()
        cloud.signedIn = false

        let outcome = await module.start()

        XCTAssertEqual(outcome, .notSignedIn)
        XCTAssertFalse(module.isUnfinished)
        XCTAssertEqual(try count("Customer"), 1)
        XCTAssertNotNil(UserManager.shared.sessionUserId)
        XCTAssertEqual(cloud.clearedCodes, [])
    }

    func testCommittedWipeKeepsSessionReadyAndStaysFinishing() async throws {
        try seedAccount()

        let outcome = await module.start()

        XCTAssertEqual(outcome, .finishing)
        XCTAssertTrue(module.isUnfinished)
        for name in ["SiteDocument", "InspectionItem", "Inspection", "Customer", "CatalogName", "User"] {
            XCTAssertEqual(try count(name), 0, name)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: photoURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: cacheMarker.path))
        XCTAssertNil(ImageCacheManager.shared.getImageFromMemory(forKey: "delete-account"))
        XCTAssertNil(isolated.defaults.string(forKey: "securityQuestion_delete@example.com"))
        XCTAssertNil(isolated.defaults.string(forKey: "securityAnswer_delete@example.com"))
        XCTAssertNil(isolated.defaults.data(forKey: "securityAnswerSalt_delete@example.com"))
        let names = ReportNames(defaults: isolated.defaults)
        let company = names.storedCompany()
        XCTAssertNil(names.storedInspectorName())
        XCTAssertNil(company.name)
        XCTAssertNil(company.street)
        XCTAssertNil(company.city)
        XCTAssertNil(company.state)
        XCTAssertNil(company.zip)
        XCTAssertNil(company.phone)
        XCTAssertNil(UserManager.shared.sessionUserId)
        XCTAssertNil(UserManager.shared.lastUserId)
        let entitlement = AccessCodeCache(defaults: isolated.defaults).load()
        XCTAssertEqual(entitlement?.code, "abc")
        XCTAssertEqual(entitlement?.sessionReady, true)
        XCTAssertEqual(cloud.clearedCodes, [])
    }

    func testSecondStartDoesNotWipeAgain() async throws {
        try seedAccount()
        _ = await module.start()
        let customer = Customer(context: context)
        customer.name = "After"
        try context.save()

        let outcome = await module.start()

        XCTAssertEqual(outcome, .finishing)
        XCTAssertEqual(try count("Customer"), 1)
        XCTAssertTrue(module.isUnfinished)
    }

    func testFailedWipeLeavesTheSession() async throws {
        try seedAccount()
        module = DeleteAccount(
            cloud: cloud,
            context: { [unowned self] in self.context },
            defaults: isolated.defaults,
            storeLoaded: { false }
        )

        let outcome = await module.start()

        XCTAssertEqual(outcome, .failed)
        XCTAssertFalse(module.isUnfinished)
        XCTAssertEqual(try count("Customer"), 1)
        XCTAssertNotNil(UserManager.shared.sessionUserId)
        XCTAssertEqual(AccessCodeCache(defaults: isolated.defaults).load()?.sessionReady, true)
        XCTAssertEqual(cloud.clearedCodes, [])
    }

    func testExportThatStartedBeforeTheWipeDoesNotFinish() async throws {
        try seedAccount()
        _ = await module.start()

        await module.noteExport(
            started: Date(timeIntervalSince1970: 0),
            ended: Date(),
            failed: false
        )

        XCTAssertTrue(module.isUnfinished)
        XCTAssertEqual(AccessCodeCache(defaults: isolated.defaults).load()?.sessionReady, true)
        XCTAssertEqual(cloud.clearedCodes, [])
    }

    func testFailedExportDoesNotFinish() async throws {
        try seedAccount()
        _ = await module.start()

        await module.noteExport(started: Date(), ended: Date().addingTimeInterval(1), failed: true)

        XCTAssertTrue(module.isUnfinished)
        XCTAssertEqual(cloud.clearedCodes, [])
    }

    func testCoveringExportClearsSessionReady() async throws {
        try seedAccount()
        _ = await module.start()

        await module.noteExport(started: Date(), ended: Date().addingTimeInterval(1), failed: false)

        XCTAssertFalse(module.isUnfinished)
        XCTAssertEqual(AccessCodeCache(defaults: isolated.defaults).load()?.sessionReady, false)
        XCTAssertEqual(AccessCodeCache(defaults: isolated.defaults).load()?.code, "abc")
        XCTAssertEqual(cloud.clearedCodes, ["abc"])
    }

    func testFailedClearStaysFinishingUntilALaterCheck() async throws {
        try seedAccount()
        cloud.clearSucceeds = false
        _ = await module.start()
        await module.noteExport(started: Date(), ended: Date().addingTimeInterval(1), failed: false)
        XCTAssertTrue(module.isUnfinished)
        XCTAssertEqual(cloud.clearedCodes, ["abc"])

        cloud.clearSucceeds = true
        await module.advance()

        XCTAssertFalse(module.isUnfinished)
        XCTAssertEqual(AccessCodeCache(defaults: isolated.defaults).load()?.sessionReady, false)
        XCTAssertEqual(cloud.clearedCodes, ["abc", "abc"])
    }

    func testExportDuringTheWipeAppliesOnceTheWipeCommits() async throws {
        try seedAccount()
        let box = DeleteAccountBox()
        module = DeleteAccount(
            cloud: cloud,
            context: { [unowned self] in self.context },
            defaults: isolated.defaults,
            storeLoaded: { true },
            clearImageCache: {
                await box.module?.noteExport(started: Date(), ended: Date().addingTimeInterval(1), failed: false)
            }
        )
        box.module = module

        _ = await module.start()

        XCTAssertFalse(module.isUnfinished)
        XCTAssertEqual(AccessCodeCache(defaults: isolated.defaults).load()?.sessionReady, false)
        XCTAssertEqual(cloud.clearedCodes, ["abc"])
    }

    func testInterruptedWipeRetriesWhenICloudIsSignedIn() async throws {
        try seedAccount()
        DeleteAccountProgressStore.save(
            DeleteAccountProgress(savedAt: Date(), saved: false, exportAccepted: false),
            isolated.defaults
        )

        await module.advance()

        XCTAssertEqual(try count("Customer"), 0)
        XCTAssertTrue(module.isUnfinished)
        XCTAssertNil(UserManager.shared.sessionUserId)
    }

    private func seedAccount() throws {
        for name in ["SiteDocument", "InspectionItem", "Inspection", "Customer", "CatalogName", "User"] {
            _ = NSEntityDescription.insertNewObject(forEntityName: name, into: context)
        }
        let userId = UUID()
        let user = User(context: context)
        user.id = userId
        user.email = "Delete@Example.com"
        user.isActive = true
        try Data("photo".utf8).write(to: photoURL)
        let item = InspectionItem(context: context)
        item.setValue(photoURL.path, forKey: "photoURL")
        try FileManager.default.createDirectory(
            at: cacheMarker.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("cache".utf8).write(to: cacheMarker)
        let image = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1)).image { context in
            UIColor.black.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        }
        ImageCacheManager.shared.cacheImage(image, forKey: "delete-account")
        try context.save()
        UserManager.shared.startSession(userId: userId)
        isolated.defaults.set("q", forKey: "securityQuestion_delete@example.com")
        isolated.defaults.set("a", forKey: "securityAnswer_delete@example.com")
        isolated.defaults.set(Data([1, 2, 3]), forKey: "securityAnswerSalt_delete@example.com")
        let names = ReportNames(defaults: isolated.defaults)
        names.saveInspectorName("kept")
        names.saveCompany(name: "kept", street: "kept", city: "kept", state: "kept", zip: "kept", phone: "kept")
        let entitlementCache = AccessCodeCache(defaults: isolated.defaults)
        entitlementCache.save(CachedEntitlement(code: "abc", userRecordName: "pat", sessionReady: true))
    }

    private func count(_ name: String) throws -> Int {
        try context.count(for: NSFetchRequest<NSManagedObject>(entityName: name))
    }
}

private final class DeleteAccountBox {
    var module: DeleteAccount?
}

private final class DeleteAccountCloudFake: AccessCodeCloudClient {
    var signedIn = true
    var clearSucceeds = true
    var clearedCodes: [String] = []

    func accountAvailable() async -> Bool { signedIn }

    func inspectorAccount() async -> AccountCheck { signedIn ? .signedIn : .signedOut }

    func userRecordName() async -> String? { "pat" }

    func fetch(code: String) async -> AccessCodeRecordState { .missing }

    func claim(code: String, userRecordName: String) async -> ClaimResult { .accepted }

    func markSessionReady(code: String) async -> Bool { true }

    func clearSessionReady(code: String) async -> Bool {
        clearedCodes.append(code)
        return clearSucceeds
    }
}
