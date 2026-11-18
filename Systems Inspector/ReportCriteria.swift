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
    case importance
    case primaryLocation
    case issue
    case entryOrder
}

enum ReportOrder {
    static func inspections<T>(
        _ inspections: [T],
        by choice: SortCriteria,
        date: (T) -> Date?,
        customerName: (T) -> String
    ) -> [T] {
        switch choice {
        case .customer:
            return inspections.sorted { lhs, rhs in
                let name = customerName(lhs).localizedStandardCompare(customerName(rhs))
                if name != .orderedSame { return name == .orderedAscending }
                return dateComesFirst(date(lhs), date(rhs))
            }
        case .date, .importance, .primaryLocation, .issue, .entryOrder:
            return inspections.sorted { dateComesFirst(date($0), date($1)) }
        }
    }

    static func rows<Inspection, Item>(
        _ inspections: [Inspection],
        by choice: SortCriteria,
        date: (Inspection) -> Date?,
        customerName: (Inspection) -> String,
        items: (Inspection) -> [Item],
        sequence: (Item) -> Int32,
        importance: (Item) -> Importance,
        location: (Item) -> String,
        bayNumber: (Item) -> String?,
        issues: (Item) -> Set<Issue.Path>
    ) -> [(inspection: Inspection, item: Item)] {
        let ordered = self.inspections(
            inspections,
            by: choice == .customer ? .customer : .date,
            date: date,
            customerName: customerName
        )
        switch choice {
        case .importance, .primaryLocation, .issue:
            let flat = ordered.flatMap { inspection in
                items(inspection).map { (inspection: inspection, item: $0) }
            }
            // Equal items keep this order, so the newer Inspection stays first.
            return flat.sorted { lhs, rhs in
                itemComesFirst(
                    lhs.item,
                    rhs.item,
                    choice: choice,
                    importance: importance,
                    location: location,
                    bayNumber: bayNumber,
                    issues: issues
                )
            }
        case .date, .customer, .entryOrder:
            return ordered.flatMap { inspection in
                RecordedOrder.sorted(items(inspection), sequence: sequence).map {
                    (inspection: inspection, item: $0)
                }
            }
        }
    }

    private static func dateComesFirst(_ lhs: Date?, _ rhs: Date?) -> Bool {
        switch (lhs, rhs) {
        case let (left?, right?):
            return left > right
        case (_?, nil):
            return true
        case (nil, _?), (nil, nil):
            return false
        }
    }

    private static func itemComesFirst<Item>(
        _ lhs: Item,
        _ rhs: Item,
        choice: SortCriteria,
        importance: (Item) -> Importance,
        location: (Item) -> String,
        bayNumber: (Item) -> String?,
        issues: (Item) -> Set<Issue.Path>
    ) -> Bool {
        switch choice {
        case .importance:
            if importance(lhs) != importance(rhs) { return importance(lhs) < importance(rhs) }
            return location(lhs) < location(rhs)
        case .primaryLocation:
            let result = location(lhs).compare(location(rhs), options: [.numeric, .caseInsensitive])
            if result == .orderedSame {
                let leftBay = bayNumber(lhs) ?? ""
                let rightBay = bayNumber(rhs) ?? ""
                return leftBay.compare(rightBay, options: [.numeric, .caseInsensitive]) == .orderedAscending
            }
            return result == .orderedAscending
        case .issue:
            let leftIssue = Issue.primaryParentLabel(from: issues(lhs))
            let rightIssue = Issue.primaryParentLabel(from: issues(rhs))
            if leftIssue == rightIssue { return location(lhs) < location(rhs) }
            return leftIssue < rightIssue
        case .date, .customer, .entryOrder:
            return false
        }
    }
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
