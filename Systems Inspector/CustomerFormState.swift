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
        siteRacking.customerLine(documentCount: siteDocuments.count)
    }
}
