//
//  InspectionItemIntakeTests.swift
//  Systems InspectorTests
//

import CoreData
import UIKit
import XCTest
@testable import Systems_Inspector

final class InspectionItemIntakeTests: XCTestCase {

    var container: NSPersistentContainer!
    var context: NSManagedObjectContext!
    var sessionDefaults: SessionTestDefaults!

    override func setUp() {
        super.setUp()
        sessionDefaults = SessionTestDefaults()
        sessionDefaults.install()
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

    private func makeInspection() -> Inspection {
        let inspection = Inspection(context: context)
        inspection.id = UUID()
        return inspection
    }

    private func pixelImage(_ color: UIColor = .red) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1)).image { ctx in
            color.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        }
    }

    func testCreateSetsSequenceIssuesAndPhotoData() {
        let inspection = makeInspection()
        let damage = Issue.Path(segments: ["Upright", "Front", "Damage"])
        let form = InspectionItemFormState(
            location: "  Aisle 1  ",
            bayNumber: " B2 ",
            importance: "Needs immediate attention",
            comments: "Dented",
            issues: [damage],
            photos: [pixelImage()],
            photosChanged: true
        )
        let item = InspectionItemIntake.create(into: inspection, form: form, sequenceNumber: 7)
        XCTAssertEqual(item.sequenceNumber, 7)
        XCTAssertEqual(item.location, "Aisle 1")
        XCTAssertEqual(item.bayNumber, "B2")
        XCTAssertEqual(
            item.recordedIssues(),
            [
                Issue.Path(segments: ["Upright"]),
                Issue.Path(segments: ["Upright", "Front", "Damage"])
            ]
        )
        XCTAssertFalse(item.recordedIssues().contains(Issue.Path(segments: ["Beam"])))
        XCTAssertEqual(item.photoCount, 1)
        XCTAssertEqual(item.photoBytes().count, 1)
        XCTAssertNil(item.value(forKey: "photoURL"))
        XCTAssertEqual(item.inspection, inspection)
    }

    func testUpdateReplacesRecordedIssues() {
        let inspection = makeInspection()
        let upright = Issue.Path(segments: ["Upright"])
        let beam = Issue.Path(segments: ["Beam"])
        let created = InspectionItemIntake.create(
            into: inspection,
            form: InspectionItemFormState(
                location: "A",
                issues: [upright]
            ),
            sequenceNumber: 1
        )
        XCTAssertEqual(created.recordedIssues(), [upright])
        InspectionItemIntake.update(
            created,
            form: InspectionItemFormState(
                location: "B",
                issues: [beam]
            )
        )
        XCTAssertEqual(created.recordedIssues(), [beam])
        XCTAssertEqual(created.location, "B")
    }

    func testReverseRoundTripsNestedIssue() {
        let item = InspectionItem(context: context)
        let beamFront = Issue.Path(segments: ["Beam", "Front damage"])
        item.replaceIssues([beamFront])
        let selected = item.recordedIssues()
        XCTAssertTrue(selected.contains(Issue.Path(segments: ["Beam"])))
        XCTAssertTrue(selected.contains(beamFront))
        let inspection = makeInspection()
        let roundTrip = InspectionItemIntake.create(
            into: inspection,
            form: InspectionItemFormState(
                location: "C",
                issues: selected
            ),
            sequenceNumber: 1
        )
        XCTAssertEqual(roundTrip.recordedIssues(), selected)
    }

    func testRemoveClearsPhoto() {
        let inspection = makeInspection()
        let item = InspectionItemIntake.create(
            into: inspection,
            form: InspectionItemFormState(
                location: "D",
                photos: [pixelImage()],
                photosChanged: true
            ),
            sequenceNumber: 1
        )
        XCTAssertEqual(item.photoCount, 1)
        InspectionItemIntake.update(
            item,
            form: InspectionItemFormState(
                location: "D",
                photos: [],
                photosChanged: true
            )
        )
        XCTAssertEqual(item.photoCount, 0)
        XCTAssertTrue(item.photoBytes().isEmpty)
    }

    func testSetFillsFiveSlotsAndDropsExtras() {
        let inspection = makeInspection()
        let images = (0..<6).map { _ in pixelImage() }
        let item = InspectionItemIntake.create(
            into: inspection,
            form: InspectionItemFormState(
                location: "E",
                photos: images,
                photosChanged: true
            ),
            sequenceNumber: 1
        )
        XCTAssertEqual(item.photoCount, 5)
        XCTAssertEqual(item.photoBytes().count, 5)
    }

    func testPhotoCountUsesURLWithoutRequiringFileOnDisk() {
        let item = InspectionItem(context: context)
        item.id = UUID()
        item.setValue("/tmp/systems-inspector-missing.jpg", forKey: "photoURL")
        item.setValue("/tmp/systems-inspector-missing-2.jpg", forKey: "photoURL2")
        XCTAssertEqual(item.photoCount, 2)
        XCTAssertTrue(item.hasPhoto)
    }

    func testPhotoCountSeesPhotoDataWhenURLIsMissing() {
        let item = InspectionItem(context: context)
        item.id = UUID()
        item.setValue(Data([0xFF, 0xD8, 0xFF]), forKey: "photoData3")
        XCTAssertTrue(item.hasPhoto)
        XCTAssertEqual(item.photoCount, 1)
    }

    func testPhotoCountPrefersURLSoLargeBlobsAreNotRequired() {
        let item = InspectionItem(context: context)
        item.id = UUID()
        item.setValue(Data(repeating: 1, count: 2_000_000), forKey: "photoData")
        item.setValue("/tmp/systems-inspector-slot0.jpg", forKey: "photoURL")
        let start = CFAbsoluteTimeGetCurrent()
        let count = item.photoCount
        let elapsed = CFAbsoluteTimeGetCurrent() - start
        XCTAssertEqual(count, 1)
        XCTAssertLessThan(elapsed, 0.05)
    }

    func testRemovingMiddlePhotoCompactsSlots() {
        let inspection = makeInspection()
        let item = InspectionItemIntake.create(
            into: inspection,
            form: InspectionItemFormState(
                location: "F",
                photos: [pixelImage(.red), pixelImage(.green), pixelImage(.blue)],
                photosChanged: true
            ),
            sequenceNumber: 1
        )
        XCTAssertEqual(item.photoCount, 3)
        InspectionItemIntake.update(
            item,
            form: InspectionItemFormState(
                location: "F",
                photos: [pixelImage(.red), pixelImage(.blue)],
                photosChanged: true
            )
        )
        XCTAssertEqual(item.photoCount, 2)
        XCTAssertEqual(item.photoBytes().count, 2)
    }

    func testUnchangedDoesNotClearExistingPhotos() {
        let inspection = makeInspection()
        let item = InspectionItemIntake.create(
            into: inspection,
            form: InspectionItemFormState(
                location: "G",
                photos: [pixelImage(), pixelImage(.blue)],
                photosChanged: true
            ),
            sequenceNumber: 1
        )
        XCTAssertEqual(item.photoCount, 2)
        InspectionItemIntake.update(
            item,
            form: InspectionItemFormState(location: "G2")
        )
        XCTAssertEqual(item.location, "G2")
        XCTAssertEqual(item.photoCount, 2)
        XCTAssertEqual(item.photoBytes().count, 2)
    }

    func testCreateIgnoresPhotosWhenNotChanged() {
        let inspection = makeInspection()
        let item = InspectionItemIntake.create(
            into: inspection,
            form: InspectionItemFormState(
                location: "H",
                photos: [pixelImage()],
                photosChanged: false
            ),
            sequenceNumber: 1
        )
        XCTAssertEqual(item.photoCount, 0)
    }

    func testUpdateFillsMissingUserId() {
        let userId = UUID()
        UserManager.shared.startSession(userId: userId)
        let inspection = makeInspection()
        let item = InspectionItem(context: context)
        inspection.addToItems(item)
        XCTAssertNil(item.userId)
        InspectionItemIntake.update(
            item,
            form: InspectionItemFormState(location: "E")
        )
        XCTAssertEqual(item.userId, userId)
    }

    func testHydrateCopiesFieldsIssuePathsAndPhotosWithoutMarkingChanged() {
        let inspection = makeInspection()
        let damage = Issue.Path(segments: ["Upright", "Front", "Damage"])
        let image = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).image { ctx in
            UIColor.blue.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        }
        UserManager.shared.startSession(userId: UUID())
        let item = InspectionItemIntake.create(
            into: inspection,
            form: InspectionItemFormState(
                location: "Aisle",
                bayNumber: "B2",
                importance: "Needs immediate attention",
                comments: "Dented",
                issues: [damage],
                photos: [image],
                photosChanged: true
            ),
            sequenceNumber: 1
        )

        let form = InspectionItemIntake.formState(from: item)
        XCTAssertEqual(form.location, "Aisle")
        XCTAssertEqual(form.bayNumber, "B2")
        XCTAssertEqual(form.importance, "Needs immediate attention")
        XCTAssertEqual(form.comments, "Dented")
        XCTAssertTrue(form.issues.contains(damage))
        XCTAssertEqual(form.photos.count, 1)
        XCTAssertFalse(form.photosChanged)
    }

    func testCreateAssignsNextSequenceWhenOmitted() {
        let inspection = makeInspection()
        let first = InspectionItemIntake.create(
            into: inspection,
            form: InspectionItemFormState(location: "A")
        )
        let second = InspectionItemIntake.create(
            into: inspection,
            form: InspectionItemFormState(location: "B")
        )
        XCTAssertEqual(first.sequenceNumber, 1)
        XCTAssertEqual(second.sequenceNumber, 2)
    }
}
