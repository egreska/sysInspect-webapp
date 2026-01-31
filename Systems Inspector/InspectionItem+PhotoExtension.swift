//
//  InspectionItem+PhotoExtension.swift
//  Systems Inspector
//
//  Created by Eric Greska on 6/27/25.
//

import UIKit
import CoreData

extension InspectionItem {
    
    /// Get photo from cache, CloudKit data, or local file (with caching)
    func getPhoto(completion: @escaping (UIImage?) -> Void) {
        // Generate unique cache key
        let cacheKey = getCacheKey()
        
        // Try to get from cache first (memory or disk)
        ImageCacheManager.shared.getImage(forKey: cacheKey, data: self.photoData) { image in
            if let image = image {
                completion(image)
                return
            }
            
            // Fallback to local file if cache and CloudKit data not available
            if let photoPath = self.photoURL {
                if FileManager.default.fileExists(atPath: photoPath) {
                    DispatchQueue.global(qos: .userInitiated).async {
                        if let localImage = UIImage(contentsOfFile: photoPath) {
                            print("📸 Loading photo from local file: \(URL(fileURLWithPath: photoPath).lastPathComponent)")
                            // Cache for next time
                            ImageCacheManager.shared.cacheImage(localImage, forKey: cacheKey)
                            DispatchQueue.main.async {
                                completion(localImage)
                            }
                        } else {
                            DispatchQueue.main.async {
                                completion(nil)
                            }
                        }
                    }
                    return
                }
            }
            
            print("📸 No photo available for inspection item")
            completion(nil)
        }
    }
    
    /// Synchronous version for backward compatibility (uses cache if available)
    func getPhotoSync() -> UIImage? {
        let cacheKey = getCacheKey()
        
        // Check memory cache only for synchronous calls
        if let cachedImage = ImageCacheManager.shared.getImageFromMemory(forKey: cacheKey) {
            return cachedImage
        }
        
        // First try to get from CloudKit data (most reliable)
        if let photoData = self.photoData {
            if let image = UIImage(data: photoData) {
                ImageCacheManager.shared.cacheImage(image, forKey: cacheKey)
                return image
            }
        }
        
        // Fallback to local file if CloudKit data not available
        if let photoPath = self.photoURL {
            if FileManager.default.fileExists(atPath: photoPath) {
                if let image = UIImage(contentsOfFile: photoPath) {
                    ImageCacheManager.shared.cacheImage(image, forKey: cacheKey)
                    return image
                }
            }
        }
        
        return nil
    }
    
    /// Generate unique cache key for this photo
    private func getCacheKey() -> String {
        if let itemID = self.id?.uuidString {
            return "photo_\(itemID)"
        } else if let photoPath = self.photoURL {
            return "photo_\(URL(fileURLWithPath: photoPath).lastPathComponent)"
        } else {
            return "photo_\(UUID().uuidString)"
        }
    }
    
    /// Check if this item has a photo (from either source)
    var hasPhoto: Bool {
        if photoData != nil {
            return true
        }
        
        if let photoPath = photoURL {
            return FileManager.default.fileExists(atPath: photoPath)
        }
        
        return false
    }
    
    /// Migrate local photo to CloudKit data (for existing items)
    func migrateLocalPhotoToCloudKit() {
        // Only migrate if we have local photo but no CloudKit data
        guard photoData == nil,
              let photoPath = photoURL,
              FileManager.default.fileExists(atPath: photoPath),
              let image = UIImage(contentsOfFile: photoPath),
              let imageData = image.jpegData(compressionQuality: 0.8) else {
            return
        }
        
        photoData = imageData
        print("🔄 Migrated local photo to CloudKit data (\(imageData.count) bytes)")
        
        // Cache the migrated image
        let cacheKey = getCacheKey()
        ImageCacheManager.shared.cacheImage(image, forKey: cacheKey)
        
        // Save the migration
        if let context = self.managedObjectContext {
            do {
                try context.save()
                print("✅ Photo migration saved successfully")
            } catch {
                print("❌ Failed to save photo migration: \(error)")
            }
        }
    }
    
    /// Clear cache for this photo
    func clearPhotoCache() {
        let cacheKey = getCacheKey()
        ImageCacheManager.shared.removeImage(forKey: cacheKey)
    }
}

