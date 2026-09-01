//
//  InspectionFormViewModel.swift
//  Systems Inspector
//
//  Created by Eric Greska on 5/22/25.

import Foundation
import UIKit
import CoreData

class InspectionFormViewModel: NSObject {
    private let coreDataManager = CoreDataManager.shared
    private var customer: Customer?

    private var _inspection: Inspection?
    private let isResumingInspection: Bool

    var inspection: Inspection? { _inspection }

    init(existingInspection: Inspection) {
        self._inspection = existingInspection
        self.customer = existingInspection.customer
        self.isResumingInspection = true
        super.init()

        if existingInspection.id == nil {
            existingInspection.id = UUID()
        }
        if existingInspection.date == nil {
            existingInspection.date = Date()
        }
        if existingInspection.userId == nil, let currentUserID = UserManager.shared.sessionUserId {
            existingInspection.userId = currentUserID
        }
    }

    init(customer: Customer? = nil) {
        self.customer = customer
        self.isResumingInspection = false
        super.init()
    }

    func inspectionForNewItem() -> Inspection {
        existingOrCreatedInspection()
    }

    func finish() {
        guard let currentInspection = _inspection else { return }

        if let customer = customer, currentInspection.customer == nil {
            currentInspection.customer = customer
            customer.addToInspections(currentInspection)
        }

        coreDataManager.saveContext()
    }

    func hasInspectionItems() -> Bool {
        (_inspection?.items?.count ?? 0) > 0
    }

    func abandonIfEmpty() {
        guard !isResumingInspection, let existingInspection = _inspection, !hasInspectionItems() else { return }
        if let customer = customer {
            customer.removeFromInspections(existingInspection)
        }
        existingInspection.managedObjectContext?.delete(existingInspection)
        _inspection = nil
    }

    func isResuming() -> Bool {
        isResumingInspection
    }

    func getInspectionDate() -> Date {
        _inspection?.date ?? Date()
    }

    private func existingOrCreatedInspection() -> Inspection {
        if let existingInspection = _inspection {
            return existingInspection
        }

        let context = customer?.managedObjectContext ?? coreDataManager.context
        let newInspection = Inspection(context: context)
        newInspection.id = UUID()
        newInspection.date = Date()
        newInspection.inspectorName = UserDefaults.standard.string(forKey: "inspectorName") ?? "Inspector Name"
        newInspection.customer = customer

        if let currentUserID = UserManager.shared.sessionUserId {
            newInspection.userId = currentUserID
        } else {
            print("WARNING: Creating new inspection without a currentUserID. Ensure user is logged in before creating inspections.")
        }

        if let customer = customer {
            customer.addToInspections(newInspection)
        }

        _inspection = newInspection
        return newInspection
    }
}

enum UserDefaultsKeys: String {
    case inspectorName = "inspectorName"
    case companyName = "companyName"
    case companyAddress = "companyAddress"
    case companyPhone = "companyPhone"
}

extension UserDefaults {
    func string(for key: UserDefaultsKeys) -> String? {
        return string(forKey: key.rawValue)
    }

    func set(_ value: String, for key: UserDefaultsKeys) {
        set(value, forKey: key.rawValue)
    }
}
