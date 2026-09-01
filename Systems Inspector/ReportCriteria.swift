//
//  ReportCriteria.swift
//  Systems Inspector
//
//  Created by Eric Greska on 5/22/25.
//
import Foundation

enum SortCriteria {
    case date
    case customer
    case inspectionStatus
    case importance
    case primaryLocation
    case issue
    case entryOrder
}

struct Filter: Codable, Equatable {
    let key: String
    let value: String
    
    func toDict() -> [String: String] { ["key": key, "value": value] }
    static func fromDict(_ d: [String: String]) -> Filter? {
        guard let k = d["key"], let v = d["value"] else { return nil }
        return Filter(key: k, value: v)
    }
}

/// Combined PDFs are allowed only when every inspection shares one customer record and site.
enum CombinedPDFJoinRule {
    static let mixedSelectionMessage = "Combined PDF reports can only include inspections for the same customer and site."

    static func canJoin(_ inspections: [ReportInspectionSnapshot]) -> Bool {
        guard let first = inspections.first else { return false }
        if inspections.count == 1 { return true }
        guard let firstCustomer = first.customer else { return false }
        let firstID = firstCustomer.id
        let firstSite = normalizedSite(firstCustomer.site)
        return inspections.allSatisfy { inspection in
            guard let customer = inspection.customer else { return false }
            return customer.id == firstID && normalizedSite(customer.site) == firstSite
        }
    }

    static func normalizedSite(_ site: String?) -> String {
        (site ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
