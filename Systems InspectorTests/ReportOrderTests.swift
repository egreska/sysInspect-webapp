//
//  ReportOrderTests.swift
//  Systems InspectorTests
//

import XCTest
@testable import Systems_Inspector

final class ReportOrderTests: XCTestCase {

    private let older = Date(timeIntervalSince1970: 1_000)
    private let newer = Date(timeIntervalSince1970: 2_000)

    private struct Visit {
        var name: String
        var date: Date?
        var customerName: String
        var items: [Row]
    }

    private struct Row {
        var sequenceNumber: Int32
        var importance: Importance = .monitor
        var location: String = ""
        var bayNumber: String? = nil
        var issues: Set<Issue.Path> = []
    }

    private func inspections(_ visits: [Visit], by choice: SortCriteria) -> [String] {
        ReportOrder.inspections(visits, by: choice, date: { $0.date }, customerName: { $0.customerName }).map(\.name)
    }

    private func rows(_ visits: [Visit], by choice: SortCriteria) -> [String] {
        ReportOrder.rows(
            visits,
            by: choice,
            date: { $0.date },
            customerName: { $0.customerName },
            items: { $0.items },
            sequence: { $0.sequenceNumber },
            importance: { $0.importance },
            location: { $0.location },
            bayNumber: { $0.bayNumber },
            issues: { $0.issues }
        ).map { "\($0.inspection.name):\($0.item.sequenceNumber)" }
    }

    func testReportOrder() {
        let dated = [
            Visit(name: "older", date: older, customerName: "Acme", items: [Row(sequenceNumber: 2), Row(sequenceNumber: 1)]),
            Visit(name: "newer", date: newer, customerName: "Acme", items: [Row(sequenceNumber: 2), Row(sequenceNumber: 1)]),
            Visit(name: "missing", date: nil, customerName: "Acme", items: [Row(sequenceNumber: 1)])
        ]
        XCTAssertEqual(inspections(dated, by: .date), ["newer", "older", "missing"])
        XCTAssertEqual(rows(dated, by: .date), ["newer:1", "newer:2", "older:1", "older:2", "missing:1"])

        let named = [
            Visit(name: "beta", date: newer, customerName: "Beta", items: [Row(sequenceNumber: 1)]),
            Visit(name: "acme-old", date: older, customerName: "Acme", items: [Row(sequenceNumber: 2), Row(sequenceNumber: 1)]),
            Visit(name: "blank", date: newer, customerName: "", items: [Row(sequenceNumber: 1)]),
            Visit(name: "acme-new", date: newer, customerName: "Acme", items: [Row(sequenceNumber: 1)])
        ]
        XCTAssertEqual(inspections(named, by: .customer), ["blank", "acme-new", "acme-old", "beta"])
        XCTAssertEqual(rows(named, by: .customer), ["blank:1", "acme-new:1", "acme-old:1", "acme-old:2", "beta:1"])

        let mixed = [
            Visit(name: "older", date: older, customerName: "Acme", items: [
                Row(sequenceNumber: 1, importance: .needsImmediateAttention, location: "B", issues: [Issue.Path(segments: ["Upright"])]),
                Row(sequenceNumber: 2, importance: .monitor, location: "A", bayNumber: "10", issues: [Issue.Path(segments: ["Beam"])])
            ]),
            Visit(name: "newer", date: newer, customerName: "Beta", items: [
                Row(sequenceNumber: 1, importance: .monitor, location: "A", bayNumber: "2", issues: [Issue.Path(segments: ["Beam"])]),
                Row(sequenceNumber: 2, importance: .monitor, location: "10", issues: [Issue.Path(segments: ["Upright"])])
            ])
        ]
        XCTAssertEqual(inspections(mixed, by: .importance), ["newer", "older"])
        XCTAssertEqual(rows(mixed, by: .importance), ["older:1", "newer:2", "newer:1", "older:2"])
        XCTAssertEqual(rows(mixed, by: .primaryLocation), ["newer:2", "newer:1", "older:2", "older:1"])
        XCTAssertEqual(rows(mixed, by: .issue), ["newer:1", "older:2", "newer:2", "older:1"])
        XCTAssertEqual(rows(mixed, by: .entryOrder), ["newer:1", "newer:2", "older:1", "older:2"])
    }
}
