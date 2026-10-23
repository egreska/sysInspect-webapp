//
//  PasswordRecoveryManager.swift
//  Systems Inspector
//
//  Manages password recovery through security questions
//  Created on 1/29/26.
//

import Foundation
import CoreData
import CryptoKit

/// Manages password recovery functionality
class PasswordRecoveryManager {
    static let shared = PasswordRecoveryManager()
    
    // MARK: - Security Questions
    static let availableQuestions = [
        "What was the name of your first pet?",
        "What city were you born in?",
        "What is your mother's maiden name?",
        "What was the name of your first school?",
        "What is your favorite book?",
        "What was your childhood nickname?",
        "In what city did you meet your spouse/significant other?",
        "What is the name of your favorite childhood friend?",
        "What street did you live on in third grade?",
        "What is the middle name of your oldest child?"
    ]
    
    private init() {}
    
    // MARK: - Security Question Management
    
    /// Set security question and answer for a user
    func setSecurityQuestion(
        for email: String,
        question: String,
        answer: String
    ) -> Bool {
        setSecurityQuestion(for: email, question: question, answer: answer, in: loadedSharedContext())
    }

    func setSecurityQuestion(
        for email: String,
        question: String,
        answer: String,
        in context: NSManagedObjectContext?
    ) -> Bool {
        guard validateSecurityAnswer(answer).isValid else { return false }
        let normalized = email.lowercased()
        guard let context, let user = fetchUser(email: normalized, in: context) else {
            print("❌ User not found")
            return false
        }
        let (hash, salt) = UserManager.shared.hashPasswordSecure(normalizedAnswer(answer))
        user.securityQuestion = question
        user.securityAnswerHash = hash
        user.securityAnswerSalt = salt
        do {
            try context.save()
            clearDefaults(for: normalized)
            print("✅ Security question set for \(email)")
            return true
        } catch {
            print("❌ Error setting security question: \(error)")
            return false
        }
    }
    
    /// Get security question for a user
    func getSecurityQuestion(for email: String) -> String? {
        getSecurityQuestion(for: email, in: loadedSharedContext())
    }

    func getSecurityQuestion(for email: String, in context: NSManagedObjectContext?) -> String? {
        guard let context else { return nil }
        let normalized = email.lowercased()
        adoptPhoneAnswer(for: normalized, in: context)
        return fetchUser(email: normalized, in: context)?.securityQuestion
    }
    
    /// Verify security answer. A locked email is refused before the answer is checked.
    func verifySecurityAnswer(for email: String, answer: String) -> Bool {
        verifySecurityAnswer(for: email, answer: answer, in: loadedSharedContext())
    }

    func verifySecurityAnswer(for email: String, answer: String, in context: NSManagedObjectContext?) -> Bool {
        let normalized = email.lowercased()
        if AccountLockoutManager.shared.isAccountLocked(email: normalized) {
            return false
        }
        guard let context else { return false }
        adoptPhoneAnswer(for: normalized, in: context)
        guard let user = fetchUser(email: normalized, in: context), let storedHash = user.securityAnswerHash else {
            return false
        }
        return checkAnswer(answer, hash: storedHash, salt: user.securityAnswerSalt, email: normalized) {
            let (hash, salt) = UserManager.shared.hashPasswordSecure(normalizedAnswer(answer))
            user.securityAnswerHash = hash
            user.securityAnswerSalt = salt
            try? context.save()
        }
    }

    func lockMessage(for email: String) -> String? {
        let lockout = AccountLockoutManager.shared
        guard lockout.isAccountLocked(email: email) else { return nil }
        let remaining = lockout.formatRemainingTime(lockout.getRemainingLockoutTime(email: email))
        return "Too many failed attempts. Try again in \(remaining)."
    }
    
    func clearSecurityQuestion(for email: String) {
        clearSecurityQuestion(for: email, in: loadedSharedContext())
    }

    func clearSecurityQuestion(for email: String, in context: NSManagedObjectContext?) {
        let normalized = email.lowercased()
        if let context, let user = fetchUser(email: normalized, in: context) {
            user.securityQuestion = nil
            user.securityAnswerHash = nil
            user.securityAnswerSalt = nil
            try? context.save()
        }
        clearDefaults(for: normalized)
    }

    /// Check if user has security question set up
    func hasSecurityQuestion(for email: String) -> Bool {
        hasSecurityQuestion(for: email, in: loadedSharedContext())
    }

    func hasSecurityQuestion(for email: String, in context: NSManagedObjectContext?) -> Bool {
        guard let context else { return false }
        let normalized = email.lowercased()
        adoptPhoneAnswer(for: normalized, in: context)
        guard let user = fetchUser(email: normalized, in: context) else { return false }
        return user.securityAnswerHash != nil || user.securityQuestion != nil
    }

    /// Copy a phone-only answer onto the Session once. A Session that already has an answer keeps it.
    func adoptPhoneAnswers() {
        guard let context = loadedSharedContext() else { return }
        let request: NSFetchRequest<User> = User.fetchRequest()
        guard let users = try? context.fetch(request) else { return }
        for user in users {
            guard let email = user.email else { continue }
            adoptPhoneAnswer(for: email, in: context)
        }
    }

    func adoptPhoneAnswer(for email: String, in context: NSManagedObjectContext) {
        let normalized = email.lowercased()
        guard let user = fetchUser(email: normalized, in: context) else { return }
        if user.securityAnswerHash != nil {
            clearDefaults(for: normalized)
            return
        }
        guard let hash = UserDefaults.standard.string(forKey: "securityAnswer_\(normalized)") else { return }
        user.securityQuestion = UserDefaults.standard.string(forKey: "securityQuestion_\(normalized)")
        user.securityAnswerHash = hash
        user.securityAnswerSalt = UserDefaults.standard.data(forKey: "securityAnswerSalt_\(normalized)")
        do {
            try context.save()
            clearDefaults(for: normalized)
        } catch {
            print("❌ Error copying security answer: \(error)")
        }
    }
    
    // MARK: - Password Reset
    
    /// Reset password after security verification
    func resetPassword(
        for email: String,
        newPassword: String,
        securityAnswer: String
    ) async -> (success: Bool, message: String) {
        if let locked = lockMessage(for: email) {
            return (false, locked)
        }

        guard verifySecurityAnswer(for: email, answer: securityAnswer) else {
            AnalyticsManager.shared.logPasswordReset(method: "security_question", success: false)
            if let locked = lockMessage(for: email) {
                return (false, locked)
            }
            return (false, "Security answer is incorrect.")
        }

        let replaced = await UserManager.shared.replacePassword(email: email, newPassword: newPassword)
        guard replaced else {
            return (false, "Failed to reset password.")
        }

        AccountLockoutManager.shared.manuallyUnlock(email: email)
        AnalyticsManager.shared.logPasswordReset(method: "security_question", success: true)
        print("✅ Password reset successful for \(email)")
        return (true, "Password has been reset successfully!")
    }
    
    // MARK: - Helper Methods
    
    private func loadedSharedContext() -> NSManagedObjectContext? {
        guard CoreDataManager.shared.isStoreLoaded else { return nil }
        return CoreDataManager.shared.context
    }

    private func fetchUser(email: String, in context: NSManagedObjectContext) -> User? {
        let request: NSFetchRequest<User> = User.fetchRequest()
        request.predicate = NSPredicate(format: "email == %@", email)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    private func clearDefaults(for email: String) {
        UserDefaults.standard.removeObject(forKey: "securityQuestion_\(email)")
        UserDefaults.standard.removeObject(forKey: "securityAnswer_\(email)")
        UserDefaults.standard.removeObject(forKey: "securityAnswerSalt_\(email)")
    }

    private func checkAnswer(
        _ answer: String,
        hash storedHash: String?,
        salt storedSalt: Data?,
        email: String,
        upgrade: () -> Void
    ) -> Bool {
        guard let storedHash else {
            print("❌ No security answer found")
            return false
        }
        let secret = normalizedAnswer(answer)
        let isValid = storedSalt.map {
            UserManager.shared.verifyPasswordSecure(secret, hash: storedHash, salt: $0)
        } ?? (legacyAnswerHash(answer) == storedHash)
        if isValid {
            if storedSalt == nil {
                upgrade()
            }
            print("✅ Security answer verified")
            return true
        }
        AccountLockoutManager.shared.recordFailedAttempt(email: email)
        print("❌ Security answer incorrect")
        return false
    }

    private func normalizedAnswer(_ answer: String) -> String {
        answer.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Old answers have no salt. One successful check replaces this hash.
    private func legacyAnswerHash(_ answer: String) -> String {
        let data = Data(normalizedAnswer(answer).utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    /// A new Security Answer, counted after the same trim used when it is stored.
    /// An answer already saved is not checked again.
    func validateSecurityAnswer(_ answer: String) -> (isValid: Bool, message: String) {
        if normalizedAnswer(answer).count < 8 {
            return (false, "Security answer must be at least 8 characters long.")
        }
        return (true, "Security answer meets requirements.")
    }

    /// Validate password strength
    func validatePasswordStrength(_ password: String) -> (isValid: Bool, message: String) {
        if password.count < 8 {
            return (false, "Password must be at least 8 characters long.")
        }
        
        let hasUppercase = password.rangeOfCharacter(from: .uppercaseLetters) != nil
        let hasLowercase = password.rangeOfCharacter(from: .lowercaseLetters) != nil
        let hasNumber = password.rangeOfCharacter(from: .decimalDigits) != nil
        
        if !hasUppercase {
            return (false, "Password must contain at least one uppercase letter.")
        }
        
        if !hasLowercase {
            return (false, "Password must contain at least one lowercase letter.")
        }
        
        if !hasNumber {
            return (false, "Password must contain at least one number.")
        }
        
        return (true, "Password meets requirements.")
    }
}
