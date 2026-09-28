//
//  ReportSnapshot.swift
//  Systems Inspector
//

import Foundation

struct ReportCustomerSnapshot: Equatable {
    var id: String
    var name: String
    var site: String?
    var address: String?
}

struct ReportItemSnapshot: Equatable {
    var id: UUID
    var sequenceNumber: Int32
    var location: String
    var bayNumber: String?
    var importance: Importance
    var comments: String?
    var issues: Set<Issue.Path>
    var photos: [Data]
}

enum ReportExportResult: Equatable {
    case package(ReportPackage)
    case empty
    case joinFailed
    case failed
}

struct ReportInspectionSnapshot: Equatable {
    var date: Date?
    var inspectorName: String?
    var customer: ReportCustomerSnapshot?
    var items: [ReportItemSnapshot]
}
