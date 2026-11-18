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

    func recoveryState(for email: String) -> RecoveryState {
        recoveryState(for: email, in: loadedSharedContext())
    }

    func recoveryState(for email: String, in context: NSManagedObjectContext?) -> RecoveryState {
        guard let context else { return .unavailable }
        let normalized = email.lowercased()
        guard let user = fetchUser(email: normalized, in: context) else { return .unavailable }
        UserManager.shared.absorbSyncedSecrets(for: user, defaults: .standard, in: context)
        guard let userId = user.id,
              let secret = UserManager.shared.secrets.load(userId: userId) else {
            return .waiting
        }
        if !secret.hasSecurityAnswer {
            return secret.hasPassword ? .unavailable : .waiting
        }
        guard let question = secret.securityQuestion, !question.isEmpty else { return .unavailable }
        return .question(question)
    }
    
    func getSecurityQuestion(for email: String) -> String? {
        getSecurityQuestion(for: email, in: loadedSharedContext())
    }

    func getSecurityQuestion(for email: String, in context: NSManagedObjectContext?) -> String? {
        guard case .question(let question) = recoveryState(for: email, in: context) else { return nil }
        return question
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
            UserManager.shared.absorbSyncedSecrets(for: user, defaults: .standard, in: context)
            if let userId = user.id, var secret = UserManager.shared.secrets.load(userId: userId) {
                secret.securityQuestion = nil
                secret.securityAnswerHash = nil
                secret.securityAnswerSalt = nil
                secret.securityAnswerIterations = nil
                _ = UserManager.shared.secrets.save(secret, userId: userId)
            }
            clearSyncedAnswer(on: user, in: context)
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
        guard let user = fetchUser(email: normalized, in: context), let userId = user.id else { return false }
        UserManager.shared.absorbSyncedSecrets(for: user, defaults: .standard, in: context)
        return UserManager.shared.secrets.load(userId: userId)?.hasSecurityAnswer == true
    }

    /// Copy a phone-only answer into the Keychain once. A secret that already has an answer keeps it.
    func adoptPhoneAnswers() {
        guard let context = loadedSharedContext() else { return }
        let request: NSFetchRequest<User> = User.fetchRequest()
        guard let users = try? context.fetch(request) else { return }
        for user in users {
            guard user.email != nil else { continue }
            adoptPhoneAnswer(for: user.email ?? "", in: context)
        }
    }

    func adoptPhoneAnswer(for email: String, in context: NSManagedObjectContext) {
        guard let user = fetchUser(email: email.lowercased(), in: context) else { return }
        UserManager.shared.absorbSyncedSecrets(for: user, defaults: .standard, in: context)
    }
    
    // MARK: - Password Reset
    
    /// Reset password after security verification
    func resetPassword(
        for email: String,
        newPassword: String,
        securityAnswer: String
    ) async -> (success: Bool, message: String) {
        let ready = await withCheckedContinuation { continuation in
            CoreDataManager.shared.waitForStoreToLoad { ready in
                continuation.resume(returning: ready)
            }
        }
        guard ready else { return (false, "Failed to reset password.") }
        let context = loadedSharedContext()
        if let locked = lockMessage(for: email) {
            return (false, locked)
        }
        let waiting = context?.performAndWait {
            if case .waiting = self.recoveryState(for: email, in: context) {
                return true
            }
            return false
        } ?? false
        if waiting {
            return (false, SessionSecretMessage.waiting)
        }
        let strength = validatePasswordStrength(newPassword)
        guard strength.isValid else {
            return (false, strength.message)
        }
        let outcome = await resetPasswordOffMain(
            for: email,
            newPassword: newPassword,
            securityAnswer: securityAnswer,
            in: context
        )
        switch outcome {
        case .replaced:
            return (true, "Password has been reset successfully!")
        case .writeFailed:
            return (false, "Failed to reset password.")
        case .unknownEmail:
            return (false, "Security answer is incorrect.")
        case .answerRefused:
            AccountLockoutManager.shared.recordFailedAttempt(email: email)
            if let locked = lockMessage(for: email) {
                return (false, locked)
            }
            return (false, "Security answer is incorrect.")
        }
    }

    func resetPasswordOffMain(
        for email: String,
        newPassword: String,
        securityAnswer: String,
        in context: NSManagedObjectContext?
    ) async -> PasswordResetOutcome {
        guard let context else {
            AnalyticsManager.shared.logPasswordReset(method: "security_question", success: false)
            return .unknownEmail
        }
        switch await verifySecurityAnswerOffMain(for: email, answer: securityAnswer, in: context) {
        case .unknown:
            AnalyticsManager.shared.logPasswordReset(method: "security_question", success: false)
            return .unknownEmail
        case .refused:
            AnalyticsManager.shared.logPasswordReset(method: "security_question", success: false)
            return .answerRefused
        case .matched:
            break
        }
        guard await UserManager.shared.replacePasswordOffMain(
            email: email,
            newPassword: newPassword,
            in: context
        ) else {
            return .writeFailed
        }
        AccountLockoutManager.shared.manuallyUnlock(email: email)
        AnalyticsManager.shared.logPasswordReset(method: "security_question", success: true)
        return .replaced
    }

    private enum OffMainAnswer {
        case matched
        case refused
        case unknown
    }

    private func verifySecurityAnswerOffMain(
        for email: String,
        answer: String,
        in context: NSManagedObjectContext
    ) async -> OffMainAnswer {
        let normalized = email.lowercased()
        let loaded: (userID: UUID, secret: SessionSecret)? = context.performAndWait {
            guard let user = self.fetchUser(email: normalized, in: context), let userId = user.id else { return nil }
            let manager = UserManager.shared
            manager.absorbSyncedSecrets(for: user, defaults: .standard, in: context)
            guard let secret = manager.secrets.load(userId: userId) else { return nil }
            return (userId, secret)
        }
        guard let loaded else { return .unknown }
        guard loaded.secret.securityAnswerHash != nil else { return .refused }
        let valid = await answerMatches(answer, secret: loaded.secret)
        if valid {
            if loaded.secret.securityAnswerIterations == nil {
                let candidate = normalizedAnswer(answer)
                if let record = await UserManager.shared.hashPasswordSecureOffMain(candidate) {
                    context.performAndWait {
                        var upgraded = loaded.secret
                        upgraded.securityAnswerHash = record.hash
                        upgraded.securityAnswerSalt = record.salt
                        upgraded.securityAnswerIterations = SessionSecretRules.iterations
                        _ = UserManager.shared.secrets.save(upgraded, userId: loaded.userID)
                    }
                }
            }
            return .matched
        }
        return .refused
    }

    private func answerMatches(_ answer: String, secret: SessionSecret) async -> Bool {
        guard let storedHash = secret.securityAnswerHash else { return false }
        let candidate = normalizedAnswer(answer)
        if let salt = secret.securityAnswerSalt, let iterations = secret.securityAnswerIterations {
            return await UserManager.shared.verifyPasswordSecureOffMain(
                candidate,
                hash: storedHash,
                salt: salt,
                iterations: iterations
            )
        }
        return UserManager.shared.hashesMatch(legacyAnswerHash(answer), storedHash)
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

    private func clearSyncedAnswer(on user: User, in context: NSManagedObjectContext) {
        guard user.securityQuestion != nil || user.securityAnswerHash != nil || user.securityAnswerSalt != nil else {
            return
        }
        user.securityQuestion = nil
        user.securityAnswerHash = nil
        user.securityAnswerSalt = nil
        try? context.save()
    }

    private func normalizedAnswer(_ answer: String) -> String {
        SessionSecretRules.normalizedAnswer(answer)
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

enum RecoveryState: Equatable {
    case waiting
    case question(String)
    case unavailable
}

enum PasswordResetOutcome: Equatable {
    case answerRefused
    case unknownEmail
    case replaced
    case writeFailed
}
