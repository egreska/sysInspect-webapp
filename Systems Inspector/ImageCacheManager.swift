//
//  ImageCacheManager.swift
//  Systems Inspector
//
//  In-memory photo cache. Inspection item bytes stay on the item.
//

import UIKit

/// Memory cache for inspection photos. A missing key is a miss; nothing is written to disk.
class ImageCacheManager {
    static let shared = ImageCacheManager()

    private let memoryCache = NSCache<NSString, UIImage>()
    private let maxMemoryCacheSize = 50

    private init() {
        memoryCache.countLimit = maxMemoryCacheSize
        memoryCache.totalCostLimit = 50 * 1024 * 1024
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(clearMemoryCache),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }

    func getImageFromMemory(forKey key: String) -> UIImage? {
        memoryCache.object(forKey: key as NSString)
    }

    /// Returns a cached image, or decodes `data` into the cache. With no data and no memory hit, this misses.
    func getImage(
        forKey key: String,
        data: Data? = nil,
        completion: @escaping (UIImage?) -> Void
    ) {
        let cacheKey = key as NSString
        if let cachedImage = memoryCache.object(forKey: cacheKey) {
            completion(cachedImage)
            return
        }
        guard let data else {
            completion(nil)
            return
        }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let image = UIImage(data: data) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            self?.store(image, forKey: cacheKey)
            DispatchQueue.main.async { completion(image) }
        }
    }

    func cacheImage(_ image: UIImage, forKey key: String) {
        store(image, forKey: key as NSString)
    }

    /// Drops the image and the 300-point thumbnail stored for the same key.
    func removeImage(forKey key: String) {
        memoryCache.removeObject(forKey: key as NSString)
        memoryCache.removeObject(forKey: "thumb_300_\(key)" as NSString)
    }

    @objc func clearMemoryCache() {
        memoryCache.removeAllObjects()
    }

    func getThumbnail(
        forKey key: String,
        maxDimension: CGFloat = 300,
        data: Data? = nil,
        completion: @escaping (UIImage?) -> Void
    ) {
        let thumbKey = "thumb_\(Int(maxDimension))_\(key)" as NSString
        if let cached = memoryCache.object(forKey: thumbKey) {
            completion(cached)
            return
        }
        guard let data else {
            completion(nil)
            return
        }
        decodeThumbnail(from: data, maxDimension: maxDimension) { [weak self] thumb in
            if let thumb {
                self?.store(thumb, forKey: thumbKey)
            }
            completion(thumb)
        }
    }

    /// Decodes a thumbnail and does not store it. Used when the photo has no stable identity.
    func uncachedThumbnail(
        from data: Data,
        maxDimension: CGFloat = 300,
        completion: @escaping (UIImage?) -> Void
    ) {
        decodeThumbnail(from: data, maxDimension: maxDimension, completion: completion)
    }

    private func store(_ image: UIImage, forKey key: NSString) {
        memoryCache.setObject(image, forKey: key, cost: imageCost(image))
    }

    private func decodeThumbnail(
        from data: Data,
        maxDimension: CGFloat,
        completion: @escaping (UIImage?) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            let thumb = StoredPhoto.displayImage(from: data, maxPixelSize: maxDimension)
            DispatchQueue.main.async { completion(thumb) }
        }
    }

    private func imageCost(_ image: UIImage) -> Int {
        let scale = image.scale
        let size = image.size
        return Int(size.width * scale * size.height * scale * 4)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
