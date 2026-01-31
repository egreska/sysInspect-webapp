//
//  AnalyticsManager.swift
//  Systems Inspector
//
//  Centralized analytics and crash reporting
//  Created on 1/29/26.
//

import Foundation
import UIKit
import FirebaseAnalytics
import FirebaseCrashlytics

/// Manages analytics events and crash reporting
class AnalyticsManager {
    static let shared = AnalyticsManager()
    
    // MARK: - Configuration
    
    private var isEnabled = true
    private var debugMode = false
    
    // MARK: - Event Categories
    
    enum EventCategory: String {
        case authentication = "authentication"
        case customers = "customers"
        case inspections = "inspections"
        case performance = "performance"
        case security = "security"
        case errors = "errors"
        case userActions = "user_actions"
    }
    
    // MARK: - Initialization
    
    private init() {
        #if DEBUG
        debugMode = true
        #endif
        
        print("📊 AnalyticsManager initialized (Debug mode: \(debugMode))")
    }
    
    // MARK: - Analytics Events
    
    /// Log a custom event
    func logEvent(_ eventName: String, parameters: [String: Any]? = nil, category: EventCategory = .userActions) {
        guard isEnabled else { return }
        
        var enrichedParameters = parameters ?? [:]
        enrichedParameters["category"] = category.rawValue
        enrichedParameters["timestamp"] = Date().timeIntervalSince1970
        enrichedParameters["platform"] = "iOS"
        enrichedParameters["app_version"] = getAppVersion()
        
        if debugMode {
            print("📊 Analytics Event: \(eventName)")
            if let params = enrichedParameters as? [String: String] {
                print("   Parameters: \(params)")
            }
        }
        
        // Integrate with Firebase Analytics
        Analytics.logEvent(eventName, parameters: enrichedParameters)
        
        // TODO: Integrate with other analytics services
        // AppCenter.trackEvent(eventName, withProperties: enrichedParameters)
    }
    
    // MARK: - Authentication Events
    
    func logLogin(method: String, success: Bool) {
        logEvent("login", parameters: [
            "method": method,
            "success": success
        ], category: .authentication)
    }
    
    func logLogout() {
        logEvent("logout", category: .authentication)
    }
    
    func logAccountCreated() {
        logEvent("account_created", category: .authentication)
    }
    
    func logPasswordReset(method: String, success: Bool) {
        logEvent("password_reset", parameters: [
            "method": method,
            "success": success
        ], category: .authentication)
    }
    
    func logAccountLocked(attempts: Int) {
        logEvent("account_locked", parameters: [
            "failed_attempts": attempts
        ], category: .security)
    }
    
    // MARK: - Customer Events
    
    func logCustomerCreated() {
        logEvent("customer_created", category: .customers)
    }
    
    func logCustomerViewed() {
        logEvent("customer_viewed", category: .customers)
    }
    
    func logCustomerEdited() {
        logEvent("customer_edited", category: .customers)
    }
    
    func logCustomerDeleted() {
        logEvent("customer_deleted", category: .customers)
    }
    
    func logCustomerSearch(resultCount: Int) {
        logEvent("customer_search", parameters: [
            "result_count": resultCount
        ], category: .customers)
    }
    
    // MARK: - Inspection Events
    
    func logInspectionCreated(itemCount: Int) {
        logEvent("inspection_created", parameters: [
            "item_count": itemCount
        ], category: .inspections)
    }
    
    func logInspectionViewed() {
        logEvent("inspection_viewed", category: .inspections)
    }
    
    func logInspectionPhotoAdded() {
        logEvent("inspection_photo_added", category: .inspections)
    }
    
    func logReportGenerated(type: String) {
        logEvent("report_generated", parameters: [
            "report_type": type
        ], category: .inspections)
    }
    
    // MARK: - Performance Events
    
    func logPerformanceMetric(operation: String, duration: TimeInterval) {
        logEvent("performance_metric", parameters: [
            "operation": operation,
            "duration_ms": Int(duration * 1000)
        ], category: .performance)
    }
    
    func logCacheHit(cacheType: String) {
        logEvent("cache_hit", parameters: [
            "cache_type": cacheType
        ], category: .performance)
    }
    
    func logCacheMiss(cacheType: String) {
        logEvent("cache_miss", parameters: [
            "cache_type": cacheType
        ], category: .performance)
    }
    
    func logMemoryUsage(usedMB: Double, totalMB: Double) {
        logEvent("memory_usage", parameters: [
            "used_mb": usedMB,
            "total_mb": totalMB,
            "percentage": (usedMB / totalMB) * 100
        ], category: .performance)
    }
    
    // MARK: - Error Tracking
    
    func logError(_ error: Error, context: String) {
        let parameters: [String: Any] = [
            "error_description": error.localizedDescription,
            "context": context,
            "error_domain": (error as NSError).domain,
            "error_code": (error as NSError).code
        ]
        
        logEvent("error_occurred", parameters: parameters, category: .errors)
        
        if debugMode {
            print("❌ Error logged: \(error.localizedDescription) in \(context)")
        }
        
        // Log to Crashlytics
        Crashlytics.crashlytics().record(error: error)
    }
    
    func logNonFatalError(message: String, details: [String: Any]? = nil) {
        var parameters = details ?? [:]
        parameters["message"] = message
        
        logEvent("non_fatal_error", parameters: parameters, category: .errors)
        
        // Log to Crashlytics
        let error = NSError(domain: "app", code: 0, userInfo: parameters)
        Crashlytics.crashlytics().record(error: error)
    }
    
    // MARK: - User Properties
    
    func setUserProperty(value: String, forName name: String) {
        guard isEnabled else { return }
        
        if debugMode {
            print("📊 User Property Set: \(name) = \(value)")
        }
        
        // User property in Firebase
        Analytics.setUserProperty(value, forName: name)
    }
    
    func setUserID(_ userID: String) {
        guard isEnabled else { return }
        
        if debugMode {
            print("📊 User ID Set: \(userID)")
        }
        
        // User ID in Firebase
        Analytics.setUserID(userID)
        
        // User ID in Crashlytics
        Crashlytics.crashlytics().setUserID(userID)
    }
    
    // MARK: - Screen Tracking
    
    func logScreenView(screenName: String, screenClass: String) {
        logEvent("screen_view", parameters: [
            "screen_name": screenName,
            "screen_class": screenClass
        ], category: .userActions)
        
        // Log screen view to Firebase
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [
            AnalyticsParameterScreenName: screenName,
            AnalyticsParameterScreenClass: screenClass
        ])
    }
    
    // MARK: - Crash Reporting
    
    func logCrash(message: String, stackTrace: String? = nil) {
        let parameters: [String: Any] = [
            "crash_message": message,
            "stack_trace": stackTrace ?? "Not available"
        ]
        
        logEvent("crash", parameters: parameters, category: .errors)
        
        if debugMode {
            print("💥 Crash logged: \(message)")
        }
        
        // Force crash log to Crashlytics
        fatalError(message) // Only in extreme cases
    }
    
    func recordCustomKey(key: String, value: Any) {
        if debugMode {
            print("🔑 Custom Key: \(key) = \(value)")
        }
        
        // Record custom key in Crashlytics
        Crashlytics.crashlytics().setCustomValue(value, forKey: key)
    }
    
    // MARK: - Configuration
    
    func enableAnalytics() {
        isEnabled = true
        print("📊 Analytics enabled")
    }
    
    func disableAnalytics() {
        isEnabled = false
        print("📊 Analytics disabled")
    }
    
    func setDebugMode(_ enabled: Bool) {
        debugMode = enabled
        print("📊 Debug mode: \(enabled)")
    }
    
    // MARK: - Helper Methods
    
    private func getAppVersion() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        return "\(version) (\(build))"
    }
    
    private func getDeviceInfo() -> [String: String] {
        return [
            "device_model": UIDevice.current.model,
            "os_version": UIDevice.current.systemVersion,
            "device_name": UIDevice.current.name
        ]
    }
}

// MARK: - Convenience Extensions

extension AnalyticsManager {
    /// Log a timed event (call at start and end)
    func startTimedEvent(_ eventName: String) {
        recordCustomKey(key: "\(eventName)_start_time", value: Date().timeIntervalSince1970)
    }
    
    func endTimedEvent(_ eventName: String, parameters: [String: Any]? = nil) {
        // Note: Full timing implementation would require storing start time
        // and calculating duration here. For now, just log completion event.
        var params = parameters ?? [:]
        params["event_name"] = eventName
        
        logEvent("\(eventName)_completed", parameters: params)
    }
}
