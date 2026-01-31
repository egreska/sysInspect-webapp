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

enum ItemSortCriteria {
    case importance
    case primaryLocation
    case issue
    case entryOrder
}

struct Filter {
    let key: String
    let value: String
}
