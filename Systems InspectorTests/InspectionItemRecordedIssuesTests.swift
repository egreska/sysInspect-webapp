//
//  InspectionItemRecordedIssuesTests.swift
//  Systems InspectorTests
//

import CoreData
import XCTest
@testable import Systems_Inspector

final class InspectionItemRecordedIssuesTests: XCTestCase {

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
        container.loadPersistentStores { _, error in
            loadError = error
        }
        XCTAssertNil(loadError, "In-memory store failed to load: \(String(describing: loadError))")
        context = container.viewContext
    }

    override func tearDown() {
        context = nil
        container = nil
        super.tearDown()
    }

    private func makeItem() -> InspectionItem {
        let item = InspectionItem(context: context)
        item.id = UUID()
        return item
    }

    func testReplaceIssuesRecordsLeafAndAncestors() {
        let item = makeItem()
        let damage = Issue.Path(segments: ["Upright", "Front", "Damage"])
        item.replaceIssues([damage])
        XCTAssertEqual(
            item.recordedIssues(),
            [
                Issue.Path(segments: ["Upright"]),
                Issue.Path(segments: ["Upright", "Front", "Damage"])
            ]
        )
    }

    func testReplaceIssuesClearsWhenEmpty() {
        let item = makeItem()
        item.replaceIssues([Issue.Path(segments: ["Beam"])])
        item.replaceIssues([])
        XCTAssertTrue(item.recordedIssues().isEmpty)
    }

    func testReplaceIssuesReplacesPrevious() {
        let item = makeItem()
        let upright = Issue.Path(segments: ["Upright"])
        let beam = Issue.Path(segments: ["Beam"])
        item.replaceIssues([upright])
        item.replaceIssues([beam])
        XCTAssertEqual(item.recordedIssues(), [beam])
    }
}
