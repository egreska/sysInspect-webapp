//
//  DateFormatters.swift
//  Systems Inspector
//
//  Reusable, cached DateFormatter instances for performance.
//

import Foundation

/// Shared DateFormatter instances. DateFormatter is expensive to create;
/// reuse these instead of creating new instances per use.
/// Thread-safe: use format(date:) which synchronizes access.
enum DateFormatters {
    private static let lock = NSLock()
    /// Medium date style (e.g. "Jan 29, 2026")
    static let medium: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()
    
    /// Short date style (e.g. "1/29/26")
    static let short: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        return f
    }()
    
    /// Long date style (e.g. "January 29, 2026")
    static let long: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .long
        return f
    }()
    
    /// Medium date + short time (e.g. "Jan 29, 2026 at 3:30 PM")
    static let mediumDateTime: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()
    
    /// ISO date format yyyy-MM-dd
    static let isoDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
    
    /// Filename-friendly format MMM_d_yyyy (e.g. "Jan_29_2026")
    static let filename: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM_d_yyyy"
        return f
    }()
    
    /// Timestamp format yyyy-MM-dd_HH-mm-ss
    static let timestamp: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return f
    }()
    
    /// Date and time yyyy-MM-dd HH:mm
    static let dateTime: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f
    }()
    
    /// Thread-safe format using the given formatter
    static func format(_ date: Date, using formatter: DateFormatter) -> String {
        lock.lock()
        defer { lock.unlock() }
        return formatter.string(from: date)
    }
    
    static func date(from string: String, using formatter: DateFormatter) -> Date? {
        lock.lock()
        defer { lock.unlock() }
        return formatter.date(from: string)
    }
}
