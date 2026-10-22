//
//  InspectionItemPhotoBytesTests.swift
//  Systems InspectorTests
//

import CoreData
import UIKit
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

    private func jpegFile() throws -> URL {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1))
        let image = renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        }
        let data = try XCTUnwrap(image.jpegData(compressionQuality: 0.8))
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("si-photo-\(UUID().uuidString).jpg")
        try data.write(to: url)
        tempFiles.append(url)
        return url
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

    func testStoredBytesReleaseAnInAppFileAndLeaveAnUnreadableOne() throws {
        let jpeg = try jpegFile()
        let junk = writeTempFile(Data([0x00, 0x01]))
        let item = makeItem()
        item.setValue(jpeg.path, forKey: "photoURL")
        item.setValue(junk, forKey: "photoURL2")

        let remove = item.migrateLocalPhotoToCloudKit()

        XCTAssertEqual(remove, [jpeg.path])
        XCTAssertNotNil(item.value(forKey: "photoData"))
        XCTAssertNil(item.value(forKey: "photoURL"))
        XCTAssertEqual(item.value(forKey: "photoURL2") as? String, junk)
        XCTAssertTrue(FileManager.default.fileExists(atPath: jpeg.path))

        InspectionItem.removeAppOwnedPhotoFiles(remove)
        XCTAssertFalse(FileManager.default.fileExists(atPath: jpeg.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: junk))
    }

    func testStoredBytesDoNotReleaseAFileOutsideTheApp() throws {
        let outside = URL(fileURLWithPath: "/tmp/systems-inspector-outside-\(UUID().uuidString).bin")
        try Data([0xAA]).write(to: outside)
        tempFiles.append(outside)
        let item = makeItem()
        item.setValue(Data([0x01]), forKey: "photoData")
        item.setValue(outside.path, forKey: "photoURL")

        XCTAssertEqual(item.migrateLocalPhotoToCloudKit(), [])
        XCTAssertNil(item.value(forKey: "photoURL"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: outside.path))
        XCTAssertEqual(item.appOwnedPhotoFilePaths(), [])
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
