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
    private var photoCompletionHandler: ((UIImage?) -> Void)?

    // UPDATED: Support both new and existing inspections
    private var _inspection: Inspection?
    private let isResumingInspection: Bool
    
    var inspection: Inspection {
        if let existingInspection = _inspection {
            // FIXED: Update inspector name with current setting even for existing inspections
            let currentInspectorName = UserDefaults.standard.string(forKey: "inspectorName") ?? "Inspector Name"
            existingInspection.inspectorName = currentInspectorName
            return existingInspection
        }
        
        // Create the inspection only when first accessed (lazy creation)
        let newInspection = Inspection(context: coreDataManager.context)
        newInspection.id = UUID()
        newInspection.date = Date()
        
        // FIXED: Always get current inspector name from settings
        let currentInspectorName = UserDefaults.standard.string(forKey: "inspectorName") ?? "Inspector Name"
        newInspection.inspectorName = currentInspectorName
        
        newInspection.customer = customer
        
        // Link inspection to customer if provided
        if let customer = customer {
            customer.addToInspections(newInspection)
        }
        
        _inspection = newInspection
        return newInspection
    }
    
    // Keep track of the inspection items
    private var inspectionItems: [InspectionItem] = []

    // UPDATED: Support both new inspections and resuming existing ones
    init(customer: Customer? = nil) {
        self.customer = customer
        self.isResumingInspection = false
        super.init()
    }
    
    // NEW: Initializer for resuming existing inspection
    init(existingInspection: Inspection) {
        self._inspection = existingInspection
        self.customer = existingInspection.customer
        self.isResumingInspection = true
        super.init()
        
        // Load existing inspection items
        self.inspectionItems = (existingInspection.items?.allObjects as? [InspectionItem]) ?? []
    }

    func saveInspectionItem(item: InspectionItem) {
        let currentInspection = inspection // This triggers lazy creation if needed
        
        // Add the item to the current inspection
        currentInspection.addToItems(item)
        
        // Also track it in our local array
        inspectionItems.append(item)
        
        // Save the context to persist changes
        coreDataManager.saveContext()
    }
    
    func saveCurrentInspection() {
        // For resumed inspections, always save since we're adding to existing
        // For new inspections, only create if there are items to save
        if isResumingInspection || !inspectionItems.isEmpty {
            let currentInspection = inspection // This triggers lazy creation if needed
            if let customer = customer, currentInspection.customer == nil {
                currentInspection.customer = customer
                customer.addToInspections(currentInspection)
            }
            
            coreDataManager.saveContext()
        }
    }

    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        self.photoCompletionHandler = completion
        
        // The actual presentation of camera is handled by the view controller
        // This is just setting up the callback
    }
    
    // Helper function to get all inspection items
    func getAllInspectionItems() -> [InspectionItem] {
        // Return items from existing inspection or empty array
        guard let existingInspection = _inspection else { return [] }
        return (existingInspection.items)?.allObjects as? [InspectionItem] ?? []
    }
    
    // Function to delete an inspection item
    func deleteInspectionItem(_ item: InspectionItem) {
        guard let existingInspection = _inspection else { return }
        existingInspection.removeFromItems(item)
        coreDataManager.context.delete(item)
        coreDataManager.saveContext()
    }
    
    // Function to update customer information if needed
    func updateCustomer(_ newCustomer: Customer) {
        if let oldCustomer = customer, let existingInspection = _inspection {
            oldCustomer.removeFromInspections(existingInspection)
        }
        
        customer = newCustomer
        if let existingInspection = _inspection {
            existingInspection.customer = newCustomer
            newCustomer.addToInspections(existingInspection)
            coreDataManager.saveContext()
        }
    }
    
    // Add a method to check if any inspection items have been added
    func hasInspectionItems() -> Bool {
        return !inspectionItems.isEmpty
    }
    
    // UPDATED: Only clean up if this was a new inspection with no items
    func cancelInspection() {
        if let existingInspection = _inspection, !isResumingInspection && inspectionItems.isEmpty {
            // If an inspection was created but no items were added, remove it
            if let customer = customer {
                customer.removeFromInspections(existingInspection)
            }
            coreDataManager.context.delete(existingInspection)
            coreDataManager.saveContext()
        }
    }
    
    // NEW: Helper to check if this is resuming an existing inspection
    func isResuming() -> Bool {
        return isResumingInspection
    }
    
    // NEW: Get the inspection date for display
    func getInspectionDate() -> Date {
        return _inspection?.date ?? Date()
    }
}

// MARK: - UIImagePickerControllerDelegate
extension InspectionFormViewModel: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let image = info[.originalImage] as? UIImage {
            photoCompletionHandler?(image)
        } else {
            photoCompletionHandler?(nil)
        }
        
        // The actual dismissal of the picker is handled by the view controller
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        photoCompletionHandler?(nil)
        
        // The actual dismissal of the picker is handled by the view controller
    }
}

// MARK: - UserDefaults Extension (Moved outside the extension)
enum UserDefaultsKeys: String {
    case inspectorName = "inspectorName"
    case companyName = "companyName"
    case companyAddress = "companyAddress"
    case companyPhone = "companyPhone"
}

// MARK: - UserDefaults Extension (Actual extension)
extension UserDefaults {
    // This function will now correctly use the rawValue of your enum
    func string(for key: UserDefaultsKeys) -> String? {
        return string(forKey: key.rawValue)
    }

    // This function will now correctly use the rawValue of your enum
    func set(_ value: String, for key: UserDefaultsKeys) {
        set(value, forKey: key.rawValue)
    }
}
