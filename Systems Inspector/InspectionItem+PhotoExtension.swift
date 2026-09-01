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

    func getPhotoThumbnail(maxDimension: CGFloat = 300, completion: @escaping (UIImage?) -> Void) {
        getPhotoThumbnail(at: 0, maxDimension: maxDimension, completion: completion)
    }

    func getAllPhotosSync() -> [UIImage] {
        (0..<Self.maxPhotoCount).compactMap { getPhotoSync(at: $0) }
    }

    func migrateLocalPhotoToCloudKit() {
        var packed: [(data: Data?, urlPath: String?)] = []
        for index in 0..<Self.maxPhotoCount {
            let path = photoURLString(at: index)
            var data = photoData(at: index)
            if data == nil,
               let path,
               FileManager.default.fileExists(atPath: path),
               let image = UIImage(contentsOfFile: path) {
                data = image.jpegData(compressionQuality: 0.8)
            }
            if data != nil || path != nil {
                packed.append((data, path))
            }
        }
        setPackedPhotos(packed)
    }

    func clearPhotoCache() {
        for index in 0..<Self.maxPhotoCount {
            ImageCacheManager.shared.removeImage(forKey: getCacheKey(at: index))
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
        if let image = getPhotoSync(at: index),
           let data = image.jpegData(compressionQuality: 0.8) {
            return data
        }
        return nil
    }

    private func setPackedPhotos(_ photos: [(data: Data?, urlPath: String?)]) {
        let limited = Array(photos.prefix(Self.maxPhotoCount))
        for index in 0..<Self.maxPhotoCount {
            if index < limited.count {
                setValue(limited[index].data, forKey: Self.photoDataKeys[index])
                setValue(limited[index].urlPath, forKey: Self.photoURLKeys[index])
            } else {
                setValue(nil, forKey: Self.photoDataKeys[index])
                setValue(nil, forKey: Self.photoURLKeys[index])
            }
        }
        clearPhotoCache()
    }

    private func getPhotoThumbnail(at index: Int, maxDimension: CGFloat = 300, completion: @escaping (UIImage?) -> Void) {
        let cacheKey = getCacheKey(at: index)
        if let data = photoData(at: index) {
            ImageCacheManager.shared.getThumbnail(forKey: cacheKey, maxDimension: maxDimension, data: data) { completion($0) }
            return
        }
        if let photoPath = photoURLString(at: index), FileManager.default.fileExists(atPath: photoPath) {
            DispatchQueue.global(qos: .userInitiated).async {
                guard let localImage = UIImage(contentsOfFile: photoPath) else {
                    DispatchQueue.main.async { completion(nil) }
                    return
                }
                ImageCacheManager.shared.cacheImage(localImage, forKey: cacheKey)
                ImageCacheManager.shared.getThumbnail(forKey: cacheKey, maxDimension: maxDimension, data: nil) { completion($0) }
            }
        } else {
            completion(nil)
        }
    }

    private func getPhotoSync(at index: Int) -> UIImage? {
        let cacheKey = getCacheKey(at: index)
        if let cachedImage = ImageCacheManager.shared.getImageFromMemory(forKey: cacheKey) {
            return cachedImage
        }
        if let data = photoData(at: index), let image = UIImage(data: data) {
            ImageCacheManager.shared.cacheImage(image, forKey: cacheKey)
            return image
        }
        if let photoPath = photoURLString(at: index),
           FileManager.default.fileExists(atPath: photoPath),
           let image = UIImage(contentsOfFile: photoPath) {
            ImageCacheManager.shared.cacheImage(image, forKey: cacheKey)
            return image
        }
        return nil
    }

    private func getCacheKey(at index: Int) -> String {
        if let itemID = self.id?.uuidString {
            return "photo_\(itemID)_\(index)"
        }
        if let photoPath = photoURLString(at: index) {
            return "photo_\(URL(fileURLWithPath: photoPath).lastPathComponent)"
        }
        return "photo_\(UUID().uuidString)"
    }
}
