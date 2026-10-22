import CoreData
import XCTest
@testable import Systems_Inspector

final class StoreBackupTests: XCTestCase {

    func testBackupIncludesWritesStillInTheSidecar() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let storeURL = directory.appendingPathComponent("live.sqlite")
        let backupURL = directory.appendingPathComponent("backup.sqlite")
        let model = noteModel()
        let container = NSPersistentContainer(name: "Note", managedObjectModel: model)
        let description = NSPersistentStoreDescription(url: storeURL)
        description.setOption(
            ["journal_mode": "WAL", "wal_autocheckpoint": "0"] as NSDictionary,
            forKey: NSSQLitePragmasOption
        )
        container.persistentStoreDescriptions = [description]

        var loadError: Error?
        let loaded = expectation(description: "live store")
        container.loadPersistentStores { _, error in
            loadError = error
            loaded.fulfill()
        }
        wait(for: [loaded], timeout: 10)
        XCTAssertNil(loadError)

        let note = NSManagedObject(entity: model.entities[0], insertInto: container.viewContext)
        note.setValue("latest", forKey: "title")
        try container.viewContext.save()
        XCTAssertTrue(FileManager.default.fileExists(atPath: storeURL.path + "-wal"))

        try copySQLiteStore(from: storeURL, to: backupURL)
        try? FileManager.default.removeItem(at: URL(fileURLWithPath: backupURL.path + "-wal"))
        try? FileManager.default.removeItem(at: URL(fileURLWithPath: backupURL.path + "-shm"))

        XCTAssertEqual(try title(at: backupURL, model: model), "latest")
    }

    private func noteModel() -> NSManagedObjectModel {
        let title = NSAttributeDescription()
        title.name = "title"
        title.attributeType = .stringAttributeType
        title.isOptional = true
        let note = NSEntityDescription()
        note.name = "Note"
        note.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
        note.properties = [title]
        let model = NSManagedObjectModel()
        model.entities = [note]
        return model
    }

    private func title(at url: URL, model: NSManagedObjectModel) throws -> String? {
        let container = NSPersistentContainer(name: "Backup", managedObjectModel: model)
        let description = NSPersistentStoreDescription(url: url)
        container.persistentStoreDescriptions = [description]
        var loadError: Error?
        let loaded = expectation(description: "backup store")
        container.loadPersistentStores { _, error in
            loadError = error
            loaded.fulfill()
        }
        wait(for: [loaded], timeout: 10)
        if let loadError { throw loadError }
        let request = NSFetchRequest<NSManagedObject>(entityName: "Note")
        return try container.viewContext.fetch(request).first?.value(forKey: "title") as? String
    }
}
