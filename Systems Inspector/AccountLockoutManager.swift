//
//  AccountLockoutManager.swift
//  Systems Inspector
//
//  Security feature to prevent brute force attacks
//  Created on 1/29/26.
//

import Foundation

/// Manages account lockout to prevent brute force password attacks
class AccountLockoutManager {
    static let shared = AccountLockoutManager()
    
    // MARK: - Configuration
    private let maxAttempts = 5
    private let lockoutDuration: TimeInterval = 15 * 60 // 15 minutes
    private let attemptResetTime: TimeInterval = 30 * 60 // 30 minutes - reset counter after this time
    
    // MARK: - UserDefaults Keys
    private enum Keys {
        static func failedAttempts(for email: String) -> String {
            return "failedAttempts_\(email.lowercased())"
        }
        
        static func lockoutTime(for email: String) -> String {
            return "lockoutTime_\(email.lowercased())"
        }
        
        static func lastAttemptTime(for email: String) -> String {
            return "lastAttemptTime_\(email.lowercased())"
        }
    }
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Check if an account is currently locked out
    func isAccountLocked(email: String) -> Bool {
        let lockoutTimeKey = Keys.lockoutTime(for: email)
        
        guard let lockoutTime = UserDefaults.standard.object(forKey: lockoutTimeKey) as? Date else {
            return false
        }
        
        let now = Date()
        let timeSinceLockout = now.timeIntervalSince(lockoutTime)
        
        if timeSinceLockout >= lockoutDuration {
            // Lockout period has expired, clear it
            clearLockout(for: email)
            return false
        }
        
        return true
    }
    
    /// Get remaining lockout time in seconds
    func getRemainingLockoutTime(email: String) -> TimeInterval {
        let lockoutTimeKey = Keys.lockoutTime(for: email)
        
        guard let lockoutTime = UserDefaults.standard.object(forKey: lockoutTimeKey) as? Date else {
            return 0
        }
        
        let now = Date()
        let timeSinceLockout = now.timeIntervalSince(lockoutTime)
        let remaining = lockoutDuration - timeSinceLockout
        
        return max(0, remaining)
    }
    
    /// Record a failed login attempt
    func recordFailedAttempt(email: String) {
        let failedAttemptsKey = Keys.failedAttempts(for: email)
        let lastAttemptTimeKey = Keys.lastAttemptTime(for: email)
        let lockoutTimeKey = Keys.lockoutTime(for: email)
        
        let now = Date()
        
        // Check if we should reset the counter due to time elapsed
        if let lastAttemptTime = UserDefaults.standard.object(forKey: lastAttemptTimeKey) as? Date {
            let timeSinceLastAttempt = now.timeIntervalSince(lastAttemptTime)
            
            if timeSinceLastAttempt >= attemptResetTime {
                // Reset counter if it's been too long since last attempt
                UserDefaults.standard.set(1, forKey: failedAttemptsKey)
                UserDefaults.standard.set(now, forKey: lastAttemptTimeKey)
                print("🔒 Account lockout: Reset failed attempts counter for \(email) (time elapsed)")
                return
            }
        }
        
        // Increment failed attempts
        let currentAttempts = UserDefaults.standard.integer(forKey: failedAttemptsKey)
        let newAttempts = currentAttempts + 1
        
        UserDefaults.standard.set(newAttempts, forKey: failedAttemptsKey)
        UserDefaults.standard.set(now, forKey: lastAttemptTimeKey)
        
        print("🔒 Account lockout: Failed attempt \(newAttempts)/\(maxAttempts) for \(email)")
        
        // Check if we should lock the account
        if newAttempts >= maxAttempts {
            UserDefaults.standard.set(now, forKey: lockoutTimeKey)
            print("⛔ Account locked for \(email) - too many failed attempts")
            
            // Log lockout event
            AnalyticsManager.shared.logAccountLocked(attempts: newAttempts)
            
            // Post notification for UI
            NotificationCenter.default.post(name: .accountLocked, object: nil, userInfo: ["email": email])
        }
    }
    
    /// Record a successful login (clears all lockout data)
    func recordSuccessfulLogin(email: String) {
        clearLockout(for: email)
        print("✅ Account lockout: Cleared lockout data for \(email) after successful login")
    }
    
    /// Get current failed attempt count
    func getFailedAttempts(email: String) -> Int {
        let failedAttemptsKey = Keys.failedAttempts(for: email)
        return UserDefaults.standard.integer(forKey: failedAttemptsKey)
    }
    
    /// Get remaining attempts before lockout
    func getRemainingAttempts(email: String) -> Int {
        let currentAttempts = getFailedAttempts(email: email)
        return max(0, maxAttempts - currentAttempts)
    }
    
    // MARK: - Private Methods
    
    private func clearLockout(for email: String) {
        let failedAttemptsKey = Keys.failedAttempts(for: email)
        let lockoutTimeKey = Keys.lockoutTime(for: email)
        let lastAttemptTimeKey = Keys.lastAttemptTime(for: email)
        
        UserDefaults.standard.removeObject(forKey: failedAttemptsKey)
        UserDefaults.standard.removeObject(forKey: lockoutTimeKey)
        UserDefaults.standard.removeObject(forKey: lastAttemptTimeKey)
    }
    
    // MARK: - Admin Methods (for testing/support)
    
    /// Manually unlock an account (admin/support function)
    func manuallyUnlock(email: String) {
        clearLockout(for: email)
        print("🔓 Account manually unlocked for \(email)")
    }
    
    /// Format remaining time as human-readable string
    func formatRemainingTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        
        if minutes > 0 {
            return "\(minutes) minute\(minutes == 1 ? "" : "s"), \(remainingSeconds) second\(remainingSeconds == 1 ? "" : "s")"
        } else {
            return "\(remainingSeconds) second\(remainingSeconds == 1 ? "" : "s")"
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let accountLocked = Notification.Name("AccountLocked")
}
