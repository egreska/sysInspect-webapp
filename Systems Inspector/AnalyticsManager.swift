//
//  AnalyticsManager.swift
//  Systems Inspector
//

import Foundation
import UIKit
import FirebaseAnalytics
import FirebaseCrashlytics

/// Analytics and Crashlytics wrapper.
final class AnalyticsManager {
    static let shared = AnalyticsManager()

    private var isEnabled = true
    private var debugMode = false

    enum EventCategory: String {
        case authentication = "authentication"
        case security = "security"
        case userActions = "user_actions"
    }

    private init() {
        #if DEBUG
        debugMode = true
        #endif
        #if DEBUG
        print("📊 AnalyticsManager initialized (Debug mode: \(debugMode))")
        #endif
    }

    func logEvent(_ eventName: String, parameters: [String: Any]? = nil, category: EventCategory = .userActions) {
        guard isEnabled else { return }

        var enrichedParameters = parameters ?? [:]
        enrichedParameters["category"] = category.rawValue
        enrichedParameters["timestamp"] = Date().timeIntervalSince1970
        enrichedParameters["platform"] = "iOS"
        enrichedParameters["app_version"] = getAppVersion()

        #if DEBUG
        if debugMode {
            print("📊 Analytics Event: \(eventName)")
        }
        #endif

        Analytics.logEvent(eventName, parameters: enrichedParameters)
    }

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

    func setUserID(_ userID: String) {
        guard isEnabled else { return }
        #if DEBUG
        if debugMode {
            print("📊 User ID Set: \(userID)")
        }
        #endif
        Analytics.setUserID(userID)
        Crashlytics.crashlytics().setUserID(userID)
    }

    func logScreenView(screenName: String, screenClass: String) {
        logEvent("screen_view", parameters: [
            "screen_name": screenName,
            "screen_class": screenClass
        ], category: .userActions)

        Analytics.logEvent(AnalyticsEventScreenView, parameters: [
            AnalyticsParameterScreenName: screenName,
            AnalyticsParameterScreenClass: screenClass
        ])
    }

    private func getAppVersion() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        return "\(version) (\(build))"
    }
}
