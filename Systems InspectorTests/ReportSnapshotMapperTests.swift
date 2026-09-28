//
//  ReportSnapshotMapperTests.swift
//  Systems InspectorTests
//

import CoreData
import UIKit
import XCTest
@testable import Systems_Inspector

final class ReportSnapshotMapperTests: XCTestCase {

    var container: NSPersistentContainer!
    var context: NSManagedObjectContext!
    var sessionDefaults: SessionTestDefaults!

    override func setUp() {
        super.setUp()
        sessionDefaults = SessionTestDefaults()
        sessionDefaults.install()
        UserManager.shared.startSession(userId: UUID())
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

    private func pixelImage() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        }
    }

    func testMapsCustomerSiteIssuePathsAndPhotos() {
        let customer = Customer(context: context)
        customer.id = UUID()
        customer.name = "Acme"
        customer.site = "Warehouse A"
        customer.address = "1 Main"
        let inspection = Inspection(context: context)
        inspection.date = Date()
        inspection.inspectorName = "Pat"
        inspection.customer = customer
        let damage = Issue.Path(segments: ["Upright", "Front", "Damage"])
        _ = InspectionItemIntake.create(
            into: inspection,
            form: InspectionItemFormState(
                location: "Aisle",
                bayNumber: "B2",
                importance: .monitor,
                comments: nil,
                issues: [damage],
                photos: [pixelImage(), pixelImage()],
                photosChanged: true
            ),
            sequenceNumber: 3
        )

        let snapshot = ReportSnapshotMapper.snapshot(from: inspection, includePhotos: true)
        XCTAssertEqual(snapshot.customer?.id, customer.id?.uuidString)
        XCTAssertEqual(snapshot.customer?.name, "Acme")
        XCTAssertEqual(snapshot.customer?.site, "Warehouse A")
        XCTAssertEqual(snapshot.items.count, 1)
        XCTAssertEqual(snapshot.items.first?.sequenceNumber, 3)
        XCTAssertEqual(snapshot.items.first?.location, "Aisle")
        XCTAssertTrue(snapshot.items.first?.issues.contains(damage) == true)
        XCTAssertEqual(snapshot.items.first?.photos.count, 2)
    }

    func testIncludePhotosFalseOmitsPhotoBytes() {
        let customer = Customer(context: context)
        customer.id = UUID()
        customer.name = "Acme"
        let inspection = Inspection(context: context)
        inspection.customer = customer
        _ = InspectionItemIntake.create(
            into: inspection,
            form: InspectionItemFormState(
                location: "Aisle",
                bayNumber: nil,
                importance: .monitor,
                comments: nil,
                issues: [],
                photos: [pixelImage()],
                photosChanged: true
            ),
            sequenceNumber: 1
        )

        let snapshot = ReportSnapshotMapper.snapshot(from: inspection, includePhotos: false)
        XCTAssertEqual(snapshot.items.first?.photos.count, 0)
        XCTAssertTrue(CombinedPDFJoinRule.canJoin([snapshot]))
    }
}
