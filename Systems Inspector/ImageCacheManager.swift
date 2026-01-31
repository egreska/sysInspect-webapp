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
    private let cacheExpiration: TimeInterval = 7 * 24 * 60 * 60 // 7 days
    
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
    
    /// Get image from cache or load from disk/data
    func getImage(
        forKey key: String,
        data: Data? = nil,
        completion: @escaping (UIImage?) -> Void
    ) {
        let cacheKey = key as NSString
        
        // 1. Check memory cache
        if let cachedImage = memoryCache.object(forKey: cacheKey) {
            print("📸 Image loaded from memory cache: \(key)")
            AnalyticsManager.shared.logCacheHit(cacheType: "memory")
            completion(cachedImage)
            return
        }
        
        // 2. Check disk cache
        if let diskImage = loadImageFromDisk(key: key) {
            // Store in memory for faster access next time
            memoryCache.setObject(diskImage, forKey: cacheKey)
            print("📸 Image loaded from disk cache: \(key)")
            AnalyticsManager.shared.logCacheHit(cacheType: "disk")
            completion(diskImage)
            return
        }
        
        // 3. Load from data if provided
        if let data = data {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                if let image = UIImage(data: data) {
                    // Cache the image
                    self?.cacheImage(image, forKey: key)
                    DispatchQueue.main.async {
                        print("📸 Image loaded from data: \(key)")
                        completion(image)
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(nil)
                    }
                }
            }
        } else {
            AnalyticsManager.shared.logCacheMiss(cacheType: "image")
            completion(nil)
        }
    }
    
    /// Cache an image (both memory and disk)
    func cacheImage(_ image: UIImage, forKey key: String) {
        let cacheKey = key as NSString
        
        // Store in memory cache
        memoryCache.setObject(image, forKey: cacheKey)
        
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
        print("🗑️ Memory cache cleared")
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
                
                print("🗑️ Disk cache cleared")
                
                DispatchQueue.main.async {
                    completion?()
                }
            } catch {
                print("❌ Error clearing disk cache: \(error)")
                DispatchQueue.main.async {
                    completion?()
                }
            }
        }
    }
    
    /// Clear expired cache entries
    func clearExpiredCache() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            
            do {
                let contents = try self.fileManager.contentsOfDirectory(
                    at: self.cacheDirectory,
                    includingPropertiesForKeys: [.contentModificationDateKey]
                )
                
                let expirationDate = Date().addingTimeInterval(-self.cacheExpiration)
                
                for fileURL in contents {
                    if let attributes = try? self.fileManager.attributesOfItem(atPath: fileURL.path),
                       let modificationDate = attributes[.modificationDate] as? Date,
                       modificationDate < expirationDate {
                        try? self.fileManager.removeItem(at: fileURL)
                        print("🗑️ Expired cache file removed: \(fileURL.lastPathComponent)")
                    }
                }
            } catch {
                print("❌ Error clearing expired cache: \(error)")
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
                print("❌ Error calculating cache size: \(error)")
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
    
    // MARK: - Private Methods
    
    private func saveImageToDisk(_ image: UIImage, key: String) {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        
        let fileURL = cacheDirectory.appendingPathComponent(key.md5Hash())
        
        do {
            try data.write(to: fileURL)
            print("💾 Image saved to disk cache: \(key)")
            
            // Check if cache size exceeds limit
            checkAndTrimCache()
        } catch {
            print("❌ Error saving image to disk: \(error)")
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
                        print("🗑️ Cache trimmed: \(fileURL.lastPathComponent)")
                    }
                }
                
                print("✅ Disk cache trimmed to \(self.formatCacheSize(currentSize))")
            } catch {
                print("❌ Error trimming disk cache: \(error)")
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
