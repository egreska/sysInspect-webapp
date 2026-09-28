//
//  ReportSnapshotMapper.swift
//  Systems Inspector
//

import CoreData

enum ReportSnapshotMapper {
    static func snapshots(from inspections: [Inspection], includePhotos: Bool = true) -> [ReportInspectionSnapshot] {
        inspections.map { snapshot(from: $0, includePhotos: includePhotos) }
    }

    static func snapshot(from inspection: Inspection, includePhotos: Bool = true) -> ReportInspectionSnapshot {
        let customer: ReportCustomerSnapshot?
        if let record = inspection.customer {
            customer = ReportCustomerSnapshot(
                id: record.id?.uuidString ?? record.objectID.uriRepresentation().absoluteString,
                name: record.name ?? "",
                site: record.site,
                address: record.address
            )
        } else {
            customer = nil
        }
        let items = ((inspection.items?.allObjects as? [InspectionItem]) ?? [])
            .sorted { $0.sequenceNumber < $1.sequenceNumber }
            .map { itemSnapshot(from: $0, includePhotos: includePhotos) }
        return ReportInspectionSnapshot(
            date: inspection.date,
            inspectorName: inspection.inspectorName,
            customer: customer,
            items: items
        )
    }

    private static func itemSnapshot(from item: InspectionItem, includePhotos: Bool) -> ReportItemSnapshot {
        ReportItemSnapshot(
            id: item.id ?? UUID(),
            sequenceNumber: item.sequenceNumber,
            location: item.location ?? "",
            bayNumber: item.bayNumber,
            importance: Importance(stored: item.importance),
            comments: item.comments,
            issues: item.recordedIssues(),
            photos: includePhotos ? item.photoBytes() : []
        )
    }
}
