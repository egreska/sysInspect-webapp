//
//  ImageCacheManager.swift
//  Systems Inspector
//
//  High-performance image caching with memory and disk storage
//  Created on 1/29/26.
//

import UIKit

/// Manages image caching for optimal performance
class ImageCacheManager {
    static let shared = ImageCacheManager()
    
    // MARK: - Cache Configuration
    fileprivate let memoryCache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    private lazy var cacheDirectory: URL = {
        let paths = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        let cacheDir = paths[0].appendingPathComponent("ImageCache")
        
        // Create directory if it doesn't exist
        if !fileManager.fileExists(atPath: cacheDir.path) {
            try? fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        }
        
        return cacheDir
    }()
    
    // Cache limits
    private let maxMemoryCacheSize = 50 // 50 images in memory
    private let maxDiskCacheSize: Int64 = 100 * 1024 * 1024 // 100 MB

    private init() {
        configureMemoryCache()
        setupMemoryWarningObserver()
    }
    
    // MARK: - Configuration
    
    private func configureMemoryCache() {
        memoryCache.countLimit = maxMemoryCacheSize
        memoryCache.totalCostLimit = 50 * 1024 * 1024 // 50 MB in memory
    }
    
    private func setupMemoryWarningObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(clearMemoryCache),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    // MARK: - Public Methods
    
    /// Check if image exists in memory cache (synchronous)
    func getImageFromMemory(forKey key: String) -> UIImage? {
        let cacheKey = key as NSString
        return memoryCache.object(forKey: cacheKey)
    }
    
    private let diskLoadQueue = DispatchQueue(label: "com.systemsinspector.imagecache.disk", qos: .userInitiated)
    
    /// Get image from cache or load from disk/data
    func getImage(
        forKey key: String,
        data: Data? = nil,
        completion: @escaping (UIImage?) -> Void
    ) {
        let cacheKey = key as NSString
        
        // 1. Check memory cache (synchronous, fast)
        if let cachedImage = memoryCache.object(forKey: cacheKey) {
            #if DEBUG
            print("📸 Image loaded from memory cache: \(key)")
            #endif
            AnalyticsManager.shared.logCacheHit(cacheType: "memory")
            completion(cachedImage)
            return
        }
        
        // 2. Check disk cache (off main thread)
        if let data = data {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }
                if let diskImage = self.loadImageFromDisk(key: key) {
                    self.memoryCache.setObject(diskImage, forKey: cacheKey, cost: self.imageCost(diskImage))
                    AnalyticsManager.shared.logCacheHit(cacheType: "disk")
                    DispatchQueue.main.async { completion(diskImage) }
                    return
                }
                if let image = UIImage(data: data) {
                    self.cacheImage(image, forKey: key)
                    DispatchQueue.main.async { completion(image) }
                } else {
                    DispatchQueue.main.async { completion(nil) }
                }
            }
        } else {
            diskLoadQueue.async { [weak self] in
                guard let self = self else { return }
                if let diskImage = self.loadImageFromDisk(key: key) {
                    self.memoryCache.setObject(diskImage, forKey: cacheKey, cost: self.imageCost(diskImage))
                    AnalyticsManager.shared.logCacheHit(cacheType: "disk")
                    DispatchQueue.main.async { completion(diskImage) }
                } else {
                    AnalyticsManager.shared.logCacheMiss(cacheType: "image")
                    DispatchQueue.main.async { completion(nil) }
                }
            }
        }
    }
    
    private func imageCost(_ image: UIImage) -> Int {
        let scale = image.scale
        let size = image.size
        return Int(size.width * scale * size.height * scale * 4)
    }
    
    /// Cache an image (both memory and disk)
    func cacheImage(_ image: UIImage, forKey key: String) {
        let cacheKey = key as NSString
        memoryCache.setObject(image, forKey: cacheKey, cost: imageCost(image))
        
        // Store in disk cache (background thread)
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.saveImageToDisk(image, key: key)
        }
    }
    
    /// Remove image from cache
    func removeImage(forKey key: String) {
        let cacheKey = key as NSString
        memoryCache.removeObject(forKey: cacheKey)
        
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.removeImageFromDisk(key: key)
        }
    }
    
    /// Clear all memory cache
    @objc func clearMemoryCache() {
        memoryCache.removeAllObjects()
        #if DEBUG
        print("🗑️ Memory cache cleared")
        #endif
    }
    
    /// Clear all disk cache
    func clearDiskCache(completion: (() -> Void)? = nil) {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            
            do {
                let contents = try self.fileManager.contentsOfDirectory(
                    at: self.cacheDirectory,
                    includingPropertiesForKeys: nil
                )
                
                for fileURL in contents {
                    try? self.fileManager.removeItem(at: fileURL)
                }
                #if DEBUG
                print("🗑️ Disk cache cleared")
                #endif
                DispatchQueue.main.async {
                    completion?()
                }
            } catch {
                #if DEBUG
                print("❌ Error clearing disk cache: \(error)")
                #endif
                DispatchQueue.main.async {
                    completion?()
                }
            }
        }
    }
    
    /// Get current disk cache size
    func getCacheSize(completion: @escaping (Int64) -> Void) {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion(0) }
                return
            }
            
            var totalSize: Int64 = 0
            
            do {
                let contents = try self.fileManager.contentsOfDirectory(
                    at: self.cacheDirectory,
                    includingPropertiesForKeys: [.fileSizeKey]
                )
                
                for fileURL in contents {
                    if let attributes = try? self.fileManager.attributesOfItem(atPath: fileURL.path),
                       let fileSize = attributes[.size] as? Int64 {
                        totalSize += fileSize
                    }
                }
            } catch {
                #if DEBUG
                print("❌ Error calculating cache size: \(error)")
                #endif
            }
            
            DispatchQueue.main.async {
                completion(totalSize)
            }
        }
    }
    
    /// Format cache size as human-readable string
    func formatCacheSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    /// Get image as thumbnail (max dimension) for list cells. Uses separate cache key.
    func getThumbnail(
        forKey key: String,
        maxDimension: CGFloat = 300,
        data: Data? = nil,
        completion: @escaping (UIImage?) -> Void
    ) {
        let thumbKey = "thumb_\(Int(maxDimension))_\(key)"
        getImage(forKey: thumbKey, data: nil) { [weak self] cached in
            if let cached = cached {
                completion(cached)
                return
            }
            self?.getImage(forKey: key, data: data) { fullImage in
                guard let full = fullImage else {
                    completion(nil)
                    return
                }
                DispatchQueue.global(qos: .userInitiated).async {
                    let thumb = Self.downscale(image: full, maxDimension: maxDimension)
                    self?.cacheImage(thumb, forKey: thumbKey)
                    DispatchQueue.main.async { completion(thumb) }
                }
            }
        }
    }
    
    private static func downscale(image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let scale = image.scale
        let maxSize = max(size.width * scale, size.height * scale)
        guard maxSize > maxDimension else { return image }
        let ratio = maxDimension / maxSize
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
    
    // MARK: - Private Methods
    
    private func saveImageToDisk(_ image: UIImage, key: String) {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        
        let fileURL = cacheDirectory.appendingPathComponent(key.md5Hash())
        
        do {
            try data.write(to: fileURL)
            #if DEBUG
            print("💾 Image saved to disk cache: \(key)")
            #endif
            // Check if cache size exceeds limit
            checkAndTrimCache()
        } catch {
            #if DEBUG
            print("❌ Error saving image to disk: \(error)")
            #endif
        }
    }
    
    private func loadImageFromDisk(key: String) -> UIImage? {
        let fileURL = cacheDirectory.appendingPathComponent(key.md5Hash())
        
        guard fileManager.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let image = UIImage(data: data) else {
            return nil
        }
        
        // Update access time
        try? fileManager.setAttributes(
            [.modificationDate: Date()],
            ofItemAtPath: fileURL.path
        )
        
        return image
    }
    
    private func removeImageFromDisk(key: String) {
        let fileURL = cacheDirectory.appendingPathComponent(key.md5Hash())
        try? fileManager.removeItem(at: fileURL)
    }
    
    private func checkAndTrimCache() {
        getCacheSize { [weak self] size in
            guard let self = self, size > self.maxDiskCacheSize else { return }
            
            // Trim cache by removing oldest files
            self.trimDiskCache()
        }
    }
    
    private func trimDiskCache() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            
            do {
                let contents = try self.fileManager.contentsOfDirectory(
                    at: self.cacheDirectory,
                    includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey]
                )
                
                // Sort by modification date (oldest first)
                let sortedFiles = contents.sorted { url1, url2 in
                    guard let date1 = try? url1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
                          let date2 = try? url2.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate else {
                        return false
                    }
                    return date1 < date2
                }
                
                var currentSize: Int64 = 0
                for fileURL in sortedFiles {
                    if let attributes = try? self.fileManager.attributesOfItem(atPath: fileURL.path),
                       let fileSize = attributes[.size] as? Int64 {
                        currentSize += fileSize
                    }
                }
                
                // Remove oldest files until under limit
                let targetSize = Int64(Double(self.maxDiskCacheSize) * 0.8) // Trim to 80% of max
                
                for fileURL in sortedFiles {
                    guard currentSize > targetSize else { break }
                    
                    if let attributes = try? self.fileManager.attributesOfItem(atPath: fileURL.path),
                       let fileSize = attributes[.size] as? Int64 {
                        try? self.fileManager.removeItem(at: fileURL)
                        currentSize -= fileSize
                        #if DEBUG
                        print("🗑️ Cache trimmed: \(fileURL.lastPathComponent)")
                        #endif
                    }
                }
                #if DEBUG
                print("✅ Disk cache trimmed to \(self.formatCacheSize(currentSize))")
                #endif
            } catch {
                #if DEBUG
                print("❌ Error trimming disk cache: \(error)")
                #endif
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - String Extension for MD5 Hashing

extension String {
    func md5Hash() -> String {
        // Simple hash for cache key generation
        var hash = 0
        for char in self.utf8 {
            hash = 31 &* hash &+ Int(char)
        }
        return "\(abs(hash))"
    }
}
