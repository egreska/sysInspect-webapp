//
//  PerformanceOptimizer.swift
//  Systems Inspector
//

import Foundation
import CoreData
import UIKit

/// Customer fetch tuning, cell height memoization, and lightweight timing for Settings diagnostics.
final class PerformanceOptimizer {
    static let shared = PerformanceOptimizer()

    private var cellHeightCache: [String: CGFloat] = [:]
    private var metrics = PerformanceMetrics()

    private init() {}

    // MARK: - Core Data

    func optimizedCustomerFetchRequest(
        pageSize: Int,
        offset: Int,
        userId: UUID
    ) -> NSFetchRequest<Customer> {
        let fetchRequest = NSFetchRequest<Customer>(entityName: "Customer")
        fetchRequest.predicate = NSPredicate(format: "userId == %@", userId as CVarArg)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        fetchRequest.fetchLimit = pageSize
        fetchRequest.fetchOffset = offset
        fetchRequest.fetchBatchSize = pageSize
        fetchRequest.propertiesToFetch = [
            "id", "name", "site", "contactName",
            "phone", "address", "city", "state",
            "zipCode", "userId", "createdDate"
        ]
        fetchRequest.returnsObjectsAsFaults = true
        #if DEBUG
        print("🚀 Optimized fetch request: limit=\(pageSize), offset=\(offset)")
        #endif
        return fetchRequest
    }

    // MARK: - Cell Height

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

    // MARK: - Memory

    func releaseUnusedResources() {
        ImageCacheManager.shared.clearMemoryCache()
        #if DEBUG
        print("🧹 Released unused resources")
        #endif
    }

    func getMemoryUsage() -> MemoryUsage {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    $0,
                    &count
                )
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

    // MARK: - Timing (Settings “Performance Stats”)

    func startTiming(_ operation: String) {
        metrics.startTime[operation] = Date()
    }

    func endTiming(_ operation: String) {
        guard let startTime = metrics.startTime[operation] else { return }
        let elapsed = Date().timeIntervalSince(startTime)
        metrics.operations[operation] = (metrics.operations[operation] ?? 0) + 1
        metrics.totalTime[operation] = (metrics.totalTime[operation] ?? 0) + elapsed
        #if DEBUG
        print("⏱️ \(operation): \(String(format: "%.2f", elapsed * 1000))ms")
        #endif
        metrics.startTime.removeValue(forKey: operation)
    }

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

    func resetMetrics() {
        metrics = PerformanceMetrics()
        #if DEBUG
        print("📊 Performance metrics reset")
        #endif
    }
}

struct MemoryUsage {
    let used: Double
    let total: Double

    var percentage: Double {
        guard total > 0 else { return 0 }
        return (used / total) * 100
    }

    var formattedString: String {
        "\(String(format: "%.1f", used))MB / \(String(format: "%.0f", total))MB (\(String(format: "%.1f", percentage))%)"
    }
}

private struct PerformanceMetrics {
    var startTime: [String: Date] = [:]
    var operations: [String: Int] = [:]
    var totalTime: [String: TimeInterval] = [:]
}
