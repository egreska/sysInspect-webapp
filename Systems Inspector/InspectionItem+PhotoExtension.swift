//
//  InspectionItem+PhotoExtension.swift
//  Systems Inspector
//

import UIKit
import CoreData

extension InspectionItem {

    static let maxPhotoCount = 5

    private static let photoDataKeys = ["photoData", "photoData2", "photoData3", "photoData4", "photoData5"]
    private static let photoURLKeys = ["photoURL", "photoURL2", "photoURL3", "photoURL4", "photoURL5"]

    static func itemsWithLocalPhotoFiles(in context: NSManagedObjectContext) throws -> [InspectionItem] {
        let request: NSFetchRequest<InspectionItem> = InspectionItem.fetchRequest()
        request.predicate = localPhotoFilePredicate
        return try context.fetch(request)
    }

    private static var localPhotoFilePredicate: NSPredicate {
        let clauses = photoURLKeys.map { "\($0) != nil" }.joined(separator: " OR ")
        return NSPredicate(format: clauses)
    }

    var photoCount: Int {
        var count = 0
        for index in 0..<Self.maxPhotoCount where hasPhoto(at: index) {
            count += 1
        }
        return count
    }

    var hasPhoto: Bool {
        (0..<Self.maxPhotoCount).contains { hasPhoto(at: $0) }
    }

    func photoBytes() -> [Data] {
        (0..<Self.maxPhotoCount).compactMap { photoBytes(at: $0) }
    }

    func replacePhotos(_ photos: [Data]) {
        let limited = Array(photos.prefix(Self.maxPhotoCount))
        for index in 0..<Self.maxPhotoCount {
            if index < limited.count {
                setValue(limited[index], forKey: Self.photoDataKeys[index])
            } else {
                setValue(nil, forKey: Self.photoDataKeys[index])
            }
            setValue(nil, forKey: Self.photoURLKeys[index])
        }
        clearPhotoCache()
    }

    func photoIndexes() -> [Int] {
        (0..<Self.maxPhotoCount).filter { hasPhoto(at: $0) }
    }

    func getPhotoThumbnail(maxDimension: CGFloat = 300, completion: @escaping (UIImage?) -> Void) {
        getPhotoThumbnail(at: 0, maxDimension: maxDimension, completion: completion)
    }

    func getPhotoThumbnail(at index: Int, maxDimension: CGFloat = 300, completion: @escaping (UIImage?) -> Void) {
        loadPhotoThumbnail(at: index, maxDimension: maxDimension, completion: completion)
    }

    /// Paths of in-app files whose bytes are now on the item. The caller deletes them after a successful save.
    func migrateLocalPhotoToCloudKit() -> [String] {
        var remove: [String] = []
        var storedBytes = false
        for index in 0..<Self.maxPhotoCount {
            let path = photoURLString(at: index)
            var data = photoData(at: index)
            if data == nil, let path {
                data = try? Data(contentsOf: URL(fileURLWithPath: path))
            }
            guard let data else { continue }
            storedBytes = true
            if let path, Self.isAppOwnedFile(path) {
                remove.append(path)
            }
            setValue(data, forKey: Self.photoDataKeys[index])
            setValue(nil, forKey: Self.photoURLKeys[index])
        }
        if storedBytes {
            clearPhotoCache()
        }
        return remove
    }

    func appOwnedPhotoFilePaths() -> [String] {
        (0..<Self.maxPhotoCount).compactMap { index in
            guard let path = photoURLString(at: index), Self.isAppOwnedFile(path) else { return nil }
            return path
        }
    }

    static func isAppOwnedFile(_ path: String) -> Bool {
        let file = URL(fileURLWithPath: path).resolvingSymlinksInPath().standardizedFileURL.path
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return false
        }
        let container = documents.deletingLastPathComponent().resolvingSymlinksInPath().standardizedFileURL.path
        return file == container || file.hasPrefix(container + "/")
    }

    static func removeAppOwnedPhotoFiles(_ paths: [String]) {
        for path in paths where isAppOwnedFile(path) {
            try? FileManager.default.removeItem(atPath: path)
        }
    }

    func clearPhotoCache() {
        for index in 0..<Self.maxPhotoCount {
            guard let key = cacheKey(at: index) else { continue }
            ImageCacheManager.shared.removeImage(forKey: key)
        }
    }

    private func hasPhoto(at index: Int) -> Bool {
        guard (0..<Self.maxPhotoCount).contains(index) else { return false }
        if let path = photoURLString(at: index), !path.isEmpty { return true }
        return photoData(at: index) != nil
    }

    private func photoData(at index: Int) -> Data? {
        guard (0..<Self.maxPhotoCount).contains(index) else { return nil }
        return value(forKey: Self.photoDataKeys[index]) as? Data
    }

    private func photoURLString(at index: Int) -> String? {
        guard (0..<Self.maxPhotoCount).contains(index) else { return nil }
        let raw = value(forKey: Self.photoURLKeys[index])
        if let path = raw as? String { return path }
        if let url = raw as? URL { return url.path }
        return nil
    }

    private func photoBytes(at index: Int) -> Data? {
        if let data = photoData(at: index) {
            return data
        }
        if let path = photoURLString(at: index),
           FileManager.default.fileExists(atPath: path),
           let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
            return data
        }
        return nil
    }

    private func loadPhotoThumbnail(at index: Int, maxDimension: CGFloat = 300, completion: @escaping (UIImage?) -> Void) {
        let key = cacheKey(at: index)
        if let data = photoData(at: index) {
            deliverThumbnail(data, key: key, maxDimension: maxDimension, completion: completion)
            return
        }
        guard let path = photoURLString(at: index), FileManager.default.fileExists(atPath: path) else {
            completion(nil)
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            let data = try? Data(contentsOf: URL(fileURLWithPath: path))
            DispatchQueue.main.async {
                guard let data else {
                    completion(nil)
                    return
                }
                self.deliverThumbnail(data, key: key, maxDimension: maxDimension, completion: completion)
            }
        }
    }

    private func deliverThumbnail(
        _ data: Data,
        key: String?,
        maxDimension: CGFloat,
        completion: @escaping (UIImage?) -> Void
    ) {
        if let key {
            ImageCacheManager.shared.getThumbnail(
                forKey: key,
                maxDimension: maxDimension,
                data: data,
                completion: completion
            )
        } else {
            ImageCacheManager.shared.uncachedThumbnail(from: data, maxDimension: maxDimension, completion: completion)
        }
    }

    /// Stable only when this item has an id, or a leftover file name. A missing identity is not cached.
    private func cacheKey(at index: Int) -> String? {
        if let itemID = self.id?.uuidString {
            return "photo_\(itemID)_\(index)"
        }
        if let photoPath = photoURLString(at: index) {
            return "photo_\(URL(fileURLWithPath: photoPath).lastPathComponent)"
        }
        return nil
    }
}
