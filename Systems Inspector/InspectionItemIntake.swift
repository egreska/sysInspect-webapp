//
//  InspectionItemIntake.swift
//  Systems Inspector
//

import CoreData
import UIKit

enum InspectionItemIntake {
    @discardableResult
    static func create(into inspection: Inspection, form: InspectionItemFormState, sequenceNumber: Int32? = nil) -> InspectionItem {
        let context = inspection.managedObjectContext ?? CoreDataManager.shared.context
        let item = InspectionItem(context: context)
        item.id = UUID()
        if let sequenceNumber {
            item.sequenceNumber = sequenceNumber
        } else {
            let existing = (inspection.items?.allObjects as? [InspectionItem]) ?? []
            item.sequenceNumber = (existing.map(\.sequenceNumber).max() ?? 0) + 1
        }
        if let userId = UserManager.shared.sessionUserId {
            item.userId = userId
        }
        applyFields(item, form)
        item.replaceIssues(form.issues)
        applyPhotos(item, form)
        inspection.addToItems(item)
        CoreDataManager.shared.saveContext()
        return item
    }

    static func update(_ item: InspectionItem, form: InspectionItemFormState) {
        applyFields(item, form)
        item.replaceIssues(form.issues)
        if item.userId == nil, let userId = UserManager.shared.sessionUserId {
            item.userId = userId
        }
        applyPhotos(item, form)
        CoreDataManager.shared.saveContext()
    }

    static func formState(from item: InspectionItem) -> InspectionItemFormState {
        InspectionItemFormState(
            location: item.location ?? "",
            bayNumber: item.bayNumber,
            importance: Importance(stored: item.importance),
            comments: item.comments,
            issues: item.recordedIssues(),
            photos: item.getAllPhotosSync(),
            photosChanged: false
        )
    }

    private static func applyFields(_ item: InspectionItem, _ form: InspectionItemFormState) {
        item.location = form.location.trimmingCharacters(in: .whitespacesAndNewlines)
        if let bay = form.bayNumber {
            let trimmed = bay.trimmingCharacters(in: .whitespacesAndNewlines)
            item.bayNumber = trimmed.isEmpty ? nil : trimmed
        } else {
            item.bayNumber = nil
        }
        item.importance = form.importance.phrase
        item.comments = form.comments
    }

    private static func applyPhotos(_ item: InspectionItem, _ form: InspectionItemFormState) {
        guard form.photosChanged else { return }
        let bytes = Array(form.photos.prefix(InspectionItem.maxPhotoCount)).compactMap { image in
            image.jpegData(compressionQuality: 0.8)
        }
        item.replacePhotos(bytes)
    }
}
