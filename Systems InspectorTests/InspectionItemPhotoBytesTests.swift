//
//  InspectionItemPhotoBytesTests.swift
//  Systems InspectorTests
//

import CoreData
import XCTest
@testable import Systems_Inspector

final class InspectionItemPhotoBytesTests: XCTestCase {

    var container: NSPersistentContainer!
    var context: NSManagedObjectContext!
    private var tempFiles: [URL] = []

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
        container.loadPersistentStores { _, error in
            loadError = error
        }
        XCTAssertNil(loadError, "In-memory store failed to load: \(String(describing: loadError))")
        context = container.viewContext
    }

    override func tearDown() {
        for url in tempFiles {
            try? FileManager.default.removeItem(at: url)
        }
        tempFiles = []
        context = nil
        container = nil
        super.tearDown()
    }

    private func makeItem() -> InspectionItem {
        let item = InspectionItem(context: context)
        item.id = UUID()
        return item
    }

    private func writeTempFile(_ data: Data) -> String {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("si-photo-bytes-\(UUID().uuidString).bin")
        try? data.write(to: url)
        tempFiles.append(url)
        return url.path
    }

    func testPhotoBytesReturnsBlobWithoutReadingURL() {
        let blob = Data([0x01, 0x02, 0x03])
        let item = makeItem()
        item.setValue(blob, forKey: "photoData")
        item.setValue(writeTempFile(Data([0xAA])), forKey: "photoURL")
        XCTAssertEqual(item.photoBytes(), [blob])
    }

    func testPhotoBytesReadsFileWhenBlobMissing() {
        let fileBytes = Data([0x10, 0x20, 0x30, 0x40])
        let item = makeItem()
        item.setValue(writeTempFile(fileBytes), forKey: "photoURL")
        XCTAssertEqual(item.photoBytes(), [fileBytes])
    }

    func testPhotoBytesOmitsEmptySlots() {
        let blob = Data([0xFF, 0xD8])
        let item = makeItem()
        item.setValue(blob, forKey: "photoData3")
        XCTAssertEqual(item.photoBytes(), [blob])
    }

    func testPhotoBytesOmitsMissingFileWithNoBlob() {
        let item = makeItem()
        item.setValue("/tmp/systems-inspector-missing-photo-bytes.jpg", forKey: "photoURL")
        XCTAssertTrue(item.hasPhoto)
        XCTAssertTrue(item.photoBytes().isEmpty)
    }

    func testReplacePhotosWritesBytesPackedLeftAndDropsExtras() {
        let item = makeItem()
        let photos = (0..<6).map { Data([$0]) }
        item.replacePhotos(photos)
        XCTAssertEqual(item.photoBytes(), Array(photos.prefix(InspectionItem.maxPhotoCount)))
        XCTAssertEqual(item.photoCount, InspectionItem.maxPhotoCount)
        XCTAssertTrue(item.hasPhoto)
        XCTAssertNil(item.value(forKey: "photoURL"))
    }

    func testReplacePhotosClearsPreviousBytesAndFileURLs() {
        let item = makeItem()
        item.setValue(Data([0x01]), forKey: "photoData")
        item.setValue(writeTempFile(Data([0xAA])), forKey: "photoURL2")
        item.replacePhotos([Data([0x02, 0x03])])
        XCTAssertEqual(item.photoBytes(), [Data([0x02, 0x03])])
        XCTAssertEqual(item.photoCount, 1)
        XCTAssertNil(item.value(forKey: "photoURL"))
        XCTAssertNil(item.value(forKey: "photoURL2"))
    }

    func testReplacePhotosEmptyClearsAll() {
        let item = makeItem()
        item.replacePhotos([Data([0x01]), Data([0x02])])
        item.replacePhotos([])
        XCTAssertTrue(item.photoBytes().isEmpty)
        XCTAssertEqual(item.photoCount, 0)
        XCTAssertFalse(item.hasPhoto)
    }

    func testItemsWithLocalPhotoFilesFindsURLNotBlobOnly() throws {
        let withFile = makeItem()
        withFile.setValue("/tmp/systems-inspector-local.jpg", forKey: "photoURL3")
        let blobOnly = makeItem()
        blobOnly.setValue(Data([0xFF]), forKey: "photoData")
        try context.save()
        let found = try InspectionItem.itemsWithLocalPhotoFiles(in: context)
        let ids = Set(found.compactMap(\.id))
        XCTAssertTrue(ids.contains(withFile.id!))
        XCTAssertFalse(ids.contains(blobOnly.id!))
    }
}
