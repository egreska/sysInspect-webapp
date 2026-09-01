//
//  ReportFromInspections.swift
//  Systems Inspector
//

import CoreData
import Foundation

enum ReportFromInspections {
    struct Selection {
        var list: [Inspection]
        var checked: [Inspection]
        var highlighted: Inspection?
    }

    static func inspections(for selection: Selection, format: ReportRequest.Format) -> [Inspection] {
        if !selection.checked.isEmpty {
            return selection.checked
        }
        if let highlighted = selection.highlighted {
            return [highlighted]
        }
        switch format {
        case .pdf:
            return selection.list.first.map { [$0] } ?? []
        case .csv:
            return selection.list
        }
    }

    static func canJoin(_ selection: Selection) -> Bool {
        let toExport = inspections(for: selection, format: .pdf)
        guard !toExport.isEmpty else { return false }
        return CombinedPDFJoinRule.canJoin(
            ReportSnapshotMapper.snapshots(from: toExport, includePhotos: false)
        )
    }

    static func run(
        _ selection: Selection,
        format: ReportRequest.Format,
        sortCriteria: SortCriteria?,
        layoutOptions: PDFLayoutOptions = PDFLayoutOptions(),
        dateRangeDescription: String?,
        header: ReportHeader,
        generator: ReportGenerator,
        completion: @escaping (ReportExportResult) -> Void
    ) {
        let toExport = inspections(for: selection, format: format)
        guard !toExport.isEmpty else {
            DispatchQueue.main.async { completion(.empty) }
            return
        }
        let objectIDs = toExport.map(\.objectID)
        CoreDataManager.shared.performBackgroundTask { context in
            let bgInspections = objectIDs.compactMap { try? context.existingObject(with: $0) as? Inspection }
            guard !bgInspections.isEmpty else {
                DispatchQueue.main.async { completion(.empty) }
                return
            }
            let snapshots = ReportSnapshotMapper.snapshots(from: bgInspections, includePhotos: true)
            let request = ReportRequest(
                inspections: snapshots,
                format: format,
                sortCriteria: sortCriteria,
                layoutOptions: layoutOptions,
                dateRangeDescription: dateRangeDescription,
                header: header
            )
            let result = generator.export(request)
            DispatchQueue.main.async { completion(result) }
        }
    }
}
