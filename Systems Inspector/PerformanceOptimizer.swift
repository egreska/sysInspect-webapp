//
//  PerformanceOptimizer.swift
//  Systems Inspector
//
//  Advanced performance optimizations for large datasets
//  Created on 1/29/26.
//

import Foundation
import CoreData
import UIKit

/// Manages performance optimizations for large datasets
class PerformanceOptimizer {
    static let shared = PerformanceOptimizer()
    
    // MARK: - Properties
    
    /// Cache for cell heights to avoid recalculation
    private var cellHeightCache: [String: CGFloat] = [:]
    
    /// Cache for computed values
    private var computedValueCache: [String: Any] = [:]
    
    /// Performance metrics
    private var metrics = PerformanceMetrics()
    
    private init() {}
    
    // MARK: - Core Data Optimizations
    
    /// Create optimized fetch request for customers with prefetching
    func optimizedCustomerFetchRequest(
        pageSize: Int,
        offset: Int,
        userId: UUID
    ) -> NSFetchRequest<Customer> {
        let fetchRequest = NSFetchRequest<Customer>(entityName: "Customer")
        
        // Predicate
        fetchRequest.predicate = NSPredicate(format: "userId == %@", userId as CVarArg)
        
        // Sort descriptors
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        // Pagination
        fetchRequest.fetchLimit = pageSize
        fetchRequest.fetchOffset = offset
        fetchRequest.fetchBatchSize = pageSize
        
        // Prefetch relationships to avoid faulting
        fetchRequest.relationshipKeyPathsForPrefetching = ["inspections"]
        
        // Only fetch properties we need (reduces memory)
        fetchRequest.propertiesToFetch = [
            "id", "name", "site", "contactName", 
            "phone", "address", "city", "state", 
            "zipCode", "userId", "createdDate"
        ]
        
        // Return objects as faults initially (memory optimization)
        fetchRequest.returnsObjectsAsFaults = true
        
        print("🚀 Optimized fetch request: limit=\(pageSize), offset=\(offset)")
        
        return fetchRequest
    }
    
    /// Create optimized fetch request for inspections
    func optimizedInspectionFetchRequest(
        for customer: Customer,
        limit: Int? = nil
    ) -> NSFetchRequest<Inspection> {
        let fetchRequest = NSFetchRequest<Inspection>(entityName: "Inspection")
        
        fetchRequest.predicate = NSPredicate(format: "customer == %@", customer)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "inspectionDate", ascending: false)]
        
        if let limit = limit {
            fetchRequest.fetchLimit = limit
            fetchRequest.fetchBatchSize = limit
        }
        
        // Prefetch inspection items
        fetchRequest.relationshipKeyPathsForPrefetching = ["items"]
        
        return fetchRequest
    }
    
    /// Batch process items in background
    func batchProcess<T>(
        items: [T],
        batchSize: Int = 50,
        process: @escaping ([T]) -> Void,
        completion: @escaping () -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            let chunks = items.chunked(into: batchSize)
            
            for chunk in chunks {
                DispatchQueue.main.async {
                    process(chunk)
                }
                // Small delay to keep UI responsive
                Thread.sleep(forTimeInterval: 0.01)
            }
            
            DispatchQueue.main.async {
                completion()
            }
        }
    }
    
    // MARK: - Cell Height Caching
    
    /// Get cached cell height or calculate and cache it
    func getCellHeight(
        for identifier: String,
        calculate: () -> CGFloat
    ) -> CGFloat {
        if let cached = cellHeightCache[identifier] {
            return cached
        }
        
        let height = calculate()
        cellHeightCache[identifier] = height
        return height
    }
    
    /// Clear cell height cache
    func clearCellHeightCache() {
        cellHeightCache.removeAll()
        print("🗑️ Cell height cache cleared")
    }
    
    // MARK: - Computed Value Caching
    
    /// Cache a computed value
    func cacheValue(_ value: Any, forKey key: String, ttl: TimeInterval = 300) {
        computedValueCache[key] = CachedValue(value: value, expiresAt: Date().addingTimeInterval(ttl))
    }
    
    /// Get cached value if not expired
    func getCachedValue(forKey key: String) -> Any? {
        guard let cached = computedValueCache[key] as? CachedValue else {
            return nil
        }
        
        if cached.isExpired {
            computedValueCache.removeValue(forKey: key)
            return nil
        }
        
        return cached.value
    }
    
    /// Clear expired cached values
    func clearExpiredCache() {
        let expiredKeys = computedValueCache.filter { _, value in
            if let cached = value as? CachedValue {
                return cached.isExpired
            }
            return false
        }.map { $0.key }
        
        for key in expiredKeys {
            computedValueCache.removeValue(forKey: key)
        }
        
        if !expiredKeys.isEmpty {
            print("🗑️ Cleared \(expiredKeys.count) expired cached values")
        }
    }
    
    // MARK: - Memory Management
    
    /// Release unused resources
    func releaseUnusedResources() {
        clearExpiredCache()
        
        // Trigger image cache memory management
        ImageCacheManager.shared.clearMemoryCache()
        
        print("🧹 Released unused resources")
    }
    
    /// Monitor memory usage
    func getMemoryUsage() -> MemoryUsage {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        guard kerr == KERN_SUCCESS else {
            return MemoryUsage(used: 0, total: 0)
        }
        
        let usedMB = Double(info.resident_size) / 1024.0 / 1024.0
        
        return MemoryUsage(
            used: usedMB,
            total: Double(ProcessInfo.processInfo.physicalMemory) / 1024.0 / 1024.0
        )
    }
    
    // MARK: - Performance Metrics
    
    /// Start timing an operation
    func startTiming(_ operation: String) {
        metrics.startTime[operation] = Date()
    }
    
    /// End timing and log result
    func endTiming(_ operation: String) {
        guard let startTime = metrics.startTime[operation] else { return }
        
        let elapsed = Date().timeIntervalSince(startTime)
        metrics.operations[operation] = (metrics.operations[operation] ?? 0) + 1
        metrics.totalTime[operation] = (metrics.totalTime[operation] ?? 0) + elapsed
        
        print("⏱️ \(operation): \(String(format: "%.2f", elapsed * 1000))ms")
        
        metrics.startTime.removeValue(forKey: operation)
    }
    
    /// Get performance summary
    func getPerformanceSummary() -> String {
        var summary = "📊 Performance Summary:\n"
        
        for (operation, count) in metrics.operations.sorted(by: { $0.key < $1.key }) {
            if let totalTime = metrics.totalTime[operation] {
                let avgTime = totalTime / Double(count)
                summary += "  \(operation): \(count) calls, avg \(String(format: "%.2f", avgTime * 1000))ms\n"
            }
        }
        
        let memory = getMemoryUsage()
        summary += "  Memory: \(String(format: "%.1f", memory.used))MB / \(String(format: "%.0f", memory.total))MB"
        
        return summary
    }
    
    /// Reset metrics
    func resetMetrics() {
        metrics = PerformanceMetrics()
        print("📊 Performance metrics reset")
    }
}

// MARK: - Supporting Types

private struct CachedValue {
    let value: Any
    let expiresAt: Date
    
    var isExpired: Bool {
        return Date() > expiresAt
    }
}

struct MemoryUsage {
    let used: Double  // MB
    let total: Double // MB
    
    var percentage: Double {
        guard total > 0 else { return 0 }
        return (used / total) * 100
    }
    
    var formattedString: String {
        return "\(String(format: "%.1f", used))MB / \(String(format: "%.0f", total))MB (\(String(format: "%.1f", percentage))%)"
    }
}

private struct PerformanceMetrics {
    var startTime: [String: Date] = [:]
    var operations: [String: Int] = [:]
    var totalTime: [String: TimeInterval] = [:]
}

// MARK: - Array Extension for Chunking

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}
