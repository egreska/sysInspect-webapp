//
//  InspectionItemFormState.swift
//  Systems Inspector
//

import UIKit

struct InspectionItemFormState {
    var location: String = ""
    var bayNumber: String?
    var importance: String = "Monitor"
    var comments: String?
    var issues: Set<Issue.Path> = []
    private(set) var photos: [UIImage] = []
    private(set) var photosChanged = false

    init(
        location: String = "",
        bayNumber: String? = nil,
        importance: String = "Monitor",
        comments: String? = nil,
        issues: Set<Issue.Path> = [],
        photos: [UIImage] = [],
        photosChanged: Bool = false
    ) {
        self.location = location
        self.bayNumber = bayNumber
        self.importance = importance
        self.comments = comments
        self.issues = issues
        self.photos = Array(photos.prefix(InspectionItem.maxPhotoCount))
        self.photosChanged = photosChanged
    }

    var isValid: Bool {
        !location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasContent: Bool {
        !location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !(bayNumber?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
            || !(comments?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
            || !issues.isEmpty
            || !photos.isEmpty
    }

    var issueDisplayLabels: [String] {
        Issue.labels(from: Issue.flags(from: issues))
    }

    var atPhotoCap: Bool {
        photos.count >= InspectionItem.maxPhotoCount
    }

    mutating func toggleImportance() {
        importance = (importance == "Monitor") ? "Needs immediate attention" : "Monitor"
    }

    @discardableResult
    mutating func addPhoto(_ image: UIImage) -> Bool {
        guard photos.count < InspectionItem.maxPhotoCount else { return false }
        photos.append(image)
        photosChanged = true
        return true
    }

    mutating func removePhoto(at index: Int) {
        guard photos.indices.contains(index) else { return }
        photos.remove(at: index)
        photosChanged = true
    }

    mutating func reset() {
        self = InspectionItemFormState()
    }
}
