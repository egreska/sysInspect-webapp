//
//  ReportFromInspectionsTests.swift
//  Systems InspectorTests
//

import CoreData
import XCTest
@testable import Systems_Inspector

final class ReportFromInspectionsTests: XCTestCase {

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

    private func makeInspection() -> Inspection {
        let inspection = Inspection(context: context)
        inspection.id = UUID()
        return inspection
    }

    private func ids(_ inspections: [Inspection]) -> [NSManagedObjectID] {
        inspections.map(\.objectID)
    }

    func testCheckedWinsOverHighlightedAndListForBothFormats() {
        let list = [makeInspection(), makeInspection(), makeInspection()]
        let selection = ReportFromInspections.Selection(
            list: list,
            checked: [list[2], list[0]],
            highlighted: list[1]
        )
        XCTAssertEqual(
            ids(ReportFromInspections.inspections(for: selection, format: .pdf)),
            ids([list[2], list[0]])
        )
        XCTAssertEqual(
            ids(ReportFromInspections.inspections(for: selection, format: .csv)),
            ids([list[2], list[0]])
        )
    }

    func testHighlightedUsedWhenNothingChecked() {
        let list = [makeInspection(), makeInspection(), makeInspection()]
        let selection = ReportFromInspections.Selection(
            list: list,
            checked: [],
            highlighted: list[1]
        )
        XCTAssertEqual(
            ids(ReportFromInspections.inspections(for: selection, format: .pdf)),
            ids([list[1]])
        )
        XCTAssertEqual(
            ids(ReportFromInspections.inspections(for: selection, format: .csv)),
            ids([list[1]])
        )
    }

    func testEmptySelectionPDFTakesFirstRowCSVTakesAll() {
        let list = [makeInspection(), makeInspection(), makeInspection()]
        let selection = ReportFromInspections.Selection(
            list: list,
            checked: [],
            highlighted: nil
        )
        XCTAssertEqual(
            ids(ReportFromInspections.inspections(for: selection, format: .pdf)),
            ids([list[0]])
        )
        XCTAssertEqual(
            ids(ReportFromInspections.inspections(for: selection, format: .csv)),
            ids(list)
        )
    }

    func testEmptyListIsEmptyForBothFormats() {
        let selection = ReportFromInspections.Selection(
            list: [],
            checked: [],
            highlighted: nil
        )
        XCTAssertTrue(ReportFromInspections.inspections(for: selection, format: .pdf).isEmpty)
        XCTAssertTrue(ReportFromInspections.inspections(for: selection, format: .csv).isEmpty)
    }
}
