//
//  PerformanceOptimizer.swift
//  Systems Inspector
//

import Foundation

/// Memory snapshot for Settings.
final class PerformanceOptimizer {
    static let shared = PerformanceOptimizer()

    private init() {}

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

    func getPerformanceSummary() -> String {
        let memory = getMemoryUsage()
        return "Memory: \(String(format: "%.1f", memory.used))MB / \(String(format: "%.0f", memory.total))MB"
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
