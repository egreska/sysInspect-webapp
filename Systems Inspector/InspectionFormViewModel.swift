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
    private var nextSequenceNumber: Int32 = 1
    private let isResumingInspection: Bool
    
    var inspection: Inspection {
        if let existingInspection = _inspection {
            // Ensure critical fields are set
            if existingInspection.id == nil {
                existingInspection.id = UUID()
            }
            if existingInspection.date == nil {
                existingInspection.date = Date()
            }
            if existingInspection.userId == nil, let currentUserID = coreDataManager.currentUserID {
                existingInspection.userId = currentUserID
            }
            
            let currentInspectorName = UserDefaults.standard.string(forKey: "inspectorName") ?? "Inspector Name"
            existingInspection.inspectorName = currentInspectorName
            
            return existingInspection
        }
        
        // Create new inspection with all required fields
        let newInspection = Inspection(context: coreDataManager.context)
        newInspection.id = UUID()
        newInspection.date = Date()
        
        let currentInspectorName = UserDefaults.standard.string(forKey: "inspectorName") ?? "Inspector Name"
        newInspection.inspectorName = currentInspectorName
        
        newInspection.customer = customer
        
        if let currentUserID = coreDataManager.currentUserID {
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

    func saveInspectionItem(item: InspectionItem, photo: UIImage?) {
            let currentInspection = inspection
            
            // ENSURE critical fields are set since they're now optional in the model
            if item.id == nil {
                item.id = UUID()
            }
            
            // NEW: Set sequence number for entry order tracking
            if item.sequenceNumber == 0 {
                item.sequenceNumber = nextSequenceNumber
                nextSequenceNumber += 1
            }
            
            if let currentUserID = coreDataManager.currentUserID {
                item.userId = currentUserID
                print("💾 Setting inspection item userId: \(currentUserID)")
            }

        
        // UPDATED: Handle photo for both local storage AND CloudKit sync
            if let photo = photo {
            // Save locally for immediate access
            let localPhotoURL = saveImageToDocuments(image: photo)
            item.photoURL = localPhotoURL?.path
            
            // CRITICAL: Save to Core Data for CloudKit sync
            if let photoData = photo.jpegData(compressionQuality: 0.8) {
                item.photoData = photoData
                print("💾 Saved photo data to Core Data for CloudKit sync (\(photoData.count) bytes)")
            }
        }
        
            currentInspection.addToItems(item)
            inspectionItems.append(item)
            
            print("💾 Saving inspection item locally with CloudKit sync - Sequence: \(item.sequenceNumber)")
            coreDataManager.saveContext()
        }
        
        // NEW: Initialize sequence number when resuming inspection
        init(existingInspection: Inspection) {
            self._inspection = existingInspection
            self.customer = existingInspection.customer
            self.isResumingInspection = true
            super.init()
            
            // Load existing inspection items
            self.inspectionItems = (existingInspection.items?.allObjects as? [InspectionItem]) ?? []
            
            // Set next sequence number based on existing items
            let maxSequence = inspectionItems.map { $0.sequenceNumber }.max() ?? 0
            self.nextSequenceNumber = maxSequence + 1
            
            // Ensure the existing inspection has a userId
            if existingInspection.userId == nil, let currentUserID = coreDataManager.currentUserID {
                existingInspection.userId = currentUserID
            }
        }

    
    // Keep track of the inspection items
    private var inspectionItems: [InspectionItem] = []

    // UPDATED: Support both new inspections and resuming existing ones
    init(customer: Customer? = nil) {
        self.customer = customer
        self.isResumingInspection = false
        super.init()
    }
    
    func saveCurrentInspection() {
        let currentInspection = inspection

        if let customer = customer, currentInspection.customer == nil {
            currentInspection.customer = customer
            customer.addToInspections(currentInspection)
        }
        
        // Ensure inspection has userId
        if currentInspection.userId == nil, let currentUserID = coreDataManager.currentUserID {
            currentInspection.userId = currentUserID
        }
        
        // Save context (CloudKit will handle sync automatically)
        print("💾 Saving current inspection locally with CloudKit sync")
        coreDataManager.saveContext()
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
        coreDataManager.deleteObject(item)
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
            // Ensure inspection has userId if customer is updated
            if existingInspection.userId == nil, let currentUserID = coreDataManager.currentUserID {
                existingInspection.userId = currentUserID
            }
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
            coreDataManager.deleteObject(existingInspection)
            print("InspectionFormViewModel: Deleted empty new inspection locally and remotely (if synced).")
        }
    }
    
    // NEW: Helper to save image to local documents
    private func saveImageToDocuments(image: UIImage) -> URL? {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }
        let fileName = "\(UUID().uuidString).jpg" // Use UUID for unique filenames
        let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(fileName)
        
        do {
            try data.write(to: fileURL)
            print("Saved image locally to: \(fileURL.lastPathComponent)")
            return fileURL
        } catch {
            print("Error saving image locally: \(error)")
            return nil
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

// MARK: - UIImagePickerControllerDelegate (Moved to UIViewController)
// This extension is not used by the ViewModel directly, but rather by the VC that presents the picker.
// It's kept here just as a placeholder/reminder of its original location.
/*
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
*/

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
