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
        let context = CoreDataManager.shared.context
        let fetchRequest: NSFetchRequest<User> = User.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "email == %@", email.lowercased())
        
        do {
            let users = try context.fetch(fetchRequest)
            guard users.first != nil else {
                print("❌ User not found")
                return false
            }
            
            // Store question and hashed answer
            let hashedAnswer = hashSecurityAnswer(answer)
            
            // Store in UserDefaults (could also add to User entity)
            let questionKey = "securityQuestion_\(email.lowercased())"
            let answerKey = "securityAnswer_\(email.lowercased())"
            
            UserDefaults.standard.set(question, forKey: questionKey)
            UserDefaults.standard.set(hashedAnswer, forKey: answerKey)
            
            print("✅ Security question set for \(email)")
            return true
            
        } catch {
            print("❌ Error setting security question: \(error)")
            return false
        }
    }
    
    /// Get security question for a user
    func getSecurityQuestion(for email: String) -> String? {
        let questionKey = "securityQuestion_\(email.lowercased())"
        return UserDefaults.standard.string(forKey: questionKey)
    }
    
    /// Verify security answer
    func verifySecurityAnswer(for email: String, answer: String) -> Bool {
        let answerKey = "securityAnswer_\(email.lowercased())"
        
        guard let storedHash = UserDefaults.standard.string(forKey: answerKey) else {
            print("❌ No security answer found")
            return false
        }
        
        let providedHash = hashSecurityAnswer(answer)
        let isValid = providedHash == storedHash
        
        if isValid {
            print("✅ Security answer verified")
        } else {
            print("❌ Security answer incorrect")
        }
        
        return isValid
    }
    
    /// Check if user has security question set up
    func hasSecurityQuestion(for email: String) -> Bool {
        let questionKey = "securityQuestion_\(email.lowercased())"
        return UserDefaults.standard.string(forKey: questionKey) != nil
    }
    
    // MARK: - Password Reset
    
    /// Reset password after security verification
    func resetPassword(
        for email: String,
        newPassword: String,
        securityAnswer: String
    ) async -> (success: Bool, message: String) {
        // Verify security answer first
        guard verifySecurityAnswer(for: email, answer: securityAnswer) else {
            // Log failed reset
            AnalyticsManager.shared.logPasswordReset(method: "security_question", success: false)
            return (false, "Security answer is incorrect.")
        }
        
        // Update password using UserManager
        let context = CoreDataManager.shared.context
        let fetchRequest: NSFetchRequest<User> = User.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "email == %@", email.lowercased())
        
        do {
            let users = try context.fetch(fetchRequest)
            guard let user = users.first else {
                return (false, "User not found.")
            }
            
            // Generate new secure password hash
            let passwordData = Data(newPassword.utf8)
            var saltBytes = [UInt8](repeating: 0, count: 32)
            _ = SecRandomCopyBytes(kSecRandomDefault, saltBytes.count, &saltBytes)
            let salt = Data(saltBytes)
            
            guard let derivedKey = try? PBKDF2.deriveKey(
                password: passwordData,
                salt: salt,
                iterations: 100_000,
                keyLength: 32
            ) else {
                return (false, "Failed to hash password.")
            }
            
            user.passwordHash = derivedKey.base64EncodedString()
            user.passwordSalt = salt
            
            try context.save()
            
            // Clear any account lockout
            AccountLockoutManager.shared.manuallyUnlock(email: email)
            
            // Log password reset
            AnalyticsManager.shared.logPasswordReset(method: "security_question", success: true)
            
            print("✅ Password reset successful for \(email)")
            return (true, "Password has been reset successfully!")
            
        } catch {
            print("❌ Error resetting password: \(error)")
            return (false, "Failed to reset password: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func hashSecurityAnswer(_ answer: String) -> String {
        // Normalize answer (lowercase, trim whitespace) for comparison
        let normalized = answer.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let data = Data(normalized.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
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
