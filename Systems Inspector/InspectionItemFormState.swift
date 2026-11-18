//
//  InspectionItemFormState.swift
//  Systems Inspector
//

import UIKit

struct InspectionItemFormState {
    /// The image and the JPEG from when that photo entered the form.
    struct Photo {
        var image: UIImage
        var jpeg: Data
    }

    var location: String = ""
    var bayNumber: String?
    var importance: Importance = .monitor
    var comments: String?
    var issues: Set<Issue.Path> = []
    private(set) var photos: [Photo] = []
    private(set) var photosChanged = false

    init(
        location: String = "",
        bayNumber: String? = nil,
        importance: Importance = .monitor,
        comments: String? = nil,
        issues: Set<Issue.Path> = [],
        photos: [Photo] = [],
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
        Issue.labels(from: issues)
    }

    var atPhotoCap: Bool {
        photos.count >= InspectionItem.maxPhotoCount
    }

    mutating func toggleImportance() {
        importance = importance.toggled
    }

    /// Stores the image and JPEG produced when the photo entered the form. Does not fit or encode again.
    @discardableResult
    mutating func addPhoto(image: UIImage, jpeg: Data) -> Bool {
        guard photos.count < InspectionItem.maxPhotoCount else { return false }
        photos.append(Photo(image: image, jpeg: jpeg))
        photosChanged = true
        return true
    }

    mutating func removePhoto(at index: Int) {
        guard photos.indices.contains(index) else { return }
        photos.remove(at: index)
        photosChanged = true
    }

    mutating func showStoredPhotos(_ stored: [(image: UIImage, jpeg: Data)]) {
        guard !photosChanged else { return }
        photos = stored.prefix(InspectionItem.maxPhotoCount).map { Photo(image: $0.image, jpeg: $0.jpeg) }
    }

    mutating func reset() {
        self = InspectionItemFormState()
    }
}
