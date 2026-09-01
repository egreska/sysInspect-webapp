//
//  CustomerFormState.swift
//  Systems Inspector
//

import Foundation

struct CustomerFormState {
    var name: String = ""
    var site: String?
    var contactName: String?
    var phone: String?
    var address: String?
    var city: String?
    var state: String?
    var zipCode: String?
    var siteRacking: SiteRacking = .empty
    var siteDocuments: [SiteDocumentFile] = []

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var siteRackingSubtitle: String {
        if siteRacking.isEmpty && siteDocuments.isEmpty { return "Not set" }
        let mfr = siteRacking.uprights.rows.first(where: { $0.hasManufacturer })?.manufacturer
            ?? siteRacking.beams.rows.first(where: { $0.hasManufacturer })?.manufacturer
            ?? siteRacking.decks.rows.first(where: { $0.hasManufacturer })?.manufacturer
        let docs = siteDocuments.count
        if let mfr, docs > 0 { return "\(docs) documents · \(mfr)" }
        if let mfr { return mfr }
        if docs == 1 { return "1 document" }
        if docs > 1 { return "\(docs) documents" }
        return "Configured"
    }
}
