//
//  UserManager.swift
//  Systems Inspector
//
//  Created by Eric Greska on 5/22/25.
//

import Foundation
import CoreData
import CryptoKit
import UIKit
import CommonCrypto

class UserManager {
    static let shared = UserManager()
    
    private let coreDataManager: CoreDataManager
    
    private init() {
        self.coreDataManager = CoreDataManager.shared
    }
    
    // MARK: - User Creation
    func createUser(email: String, password: String) async -> Bool {
        // Ensure Core Data stores are loaded first
        return await withCheckedContinuation { continuation in
            coreDataManager.waitForStoreToLoad { [weak self] success in
                guard let self = self else {
                    continuation.resume(returning: false)
                    return
                }
                
                if !success {
                    print("❌ Error: Core Data stores failed to load")
                    continuation.resume(returning: false)
                    return
                }
                
                let result = self.performUserCreation(email: email, password: password)
                continuation.resume(returning: result)
            }
        }
    }
    
    private func performUserCreation(email: String, password: String) -> Bool {
        let context = CoreDataManager.shared.context
        
        if userExists(email: email) {
            print("❌ Error creating user: User already exists with this email.")
            return false
        }
        
        do {
            let user = User(context: context)
            
            // ENSURE all critical fields are set since they're now optional in the model
            user.id = UUID()
            user.userId = user.id
            user.createdDate = Date()
            user.lastLoginDate = Date()
            user.isActive = true
            
            user.email = email.lowercased()
            
            // NEW: Secure password hashing with salt
            let (hash, salt) = hashPasswordSecure(password)
            user.passwordHash = hash
            user.passwordSalt = salt
            
            try context.save()
            print("✅ Local user created successfully")
            
            // Log account creation
            AnalyticsManager.shared.logAccountCreated()
            
            UserDefaults.standard.set(user.email, forKey: "currentUserEmail")
            UserDefaults.standard.set(user.id?.uuidString, forKey: "currentUserID")
            UserDefaults.standard.set(true, forKey: "isLoggedIn")
            
            coreDataManager.currentUserID = user.id
            
            return true
            
        } catch {
            print("❌ Error creating user: \(error)")
            return false
        }
    }

    
    // MARK: - User Authentication
    func authenticateUser(email: String, password: String) async -> Bool {
        // Ensure Core Data stores are loaded first
        return await withCheckedContinuation { continuation in
            coreDataManager.waitForStoreToLoad { [weak self] success in
                guard let self = self else {
                    continuation.resume(returning: false)
                    return
                }
                
                if !success {
                    print("❌ Error: Core Data stores failed to load")
                    continuation.resume(returning: false)
                    return
                }
                
                let result = self.performAuthentication(email: email, password: password)
                continuation.resume(returning: result)
            }
        }
    }
    
    private func performAuthentication(email: String, password: String) -> Bool {
        // Check if account is locked
        if AccountLockoutManager.shared.isAccountLocked(email: email) {
            let remainingTime = AccountLockoutManager.shared.getRemainingLockoutTime(email: email)
            let formattedTime = AccountLockoutManager.shared.formatRemainingTime(remainingTime)
            print("⛔ Account locked for \(email). Remaining time: \(formattedTime)")
            return false
        }
        
        let context = CoreDataManager.shared.context
        let fetchRequest: NSFetchRequest<User> = User.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "email == %@ AND isActive == YES", email.lowercased())
        
        do {
            let users = try context.fetch(fetchRequest)
            guard let user = users.first else {
                print("❌ User not found")
                AccountLockoutManager.shared.recordFailedAttempt(email: email)
                return false
            }
            
            var authenticationSuccessful = false
            var needsMigration = false
            
            // Check if user has new secure password hashing (has salt)
            if let storedSalt = user.passwordSalt,
               let storedHash = user.passwordHash {
                // Use new secure verification
                authenticationSuccessful = verifyPasswordSecure(password, hash: storedHash, salt: storedSalt)
                print("✅ Using secure password verification")
            } else {
                // Legacy verification for old passwords (no salt)
                let legacyHash = hashPasswordLegacy(password)
                if user.passwordHash == legacyHash {
                    authenticationSuccessful = true
                    needsMigration = true
                    print("⚠️ Using legacy password verification - will migrate to secure hashing")
                }
            }
            
            if authenticationSuccessful {
                // Clear any lockout data on successful login
                AccountLockoutManager.shared.recordSuccessfulLogin(email: email)
                
                // Migrate to secure hashing if using legacy password
                if needsMigration {
                    print("🔄 Migrating password to secure hashing...")
                    let (newHash, newSalt) = hashPasswordSecure(password)
                    user.passwordHash = newHash
                    user.passwordSalt = newSalt
                    print("✅ Password migrated to secure hashing")
                }
                
                // Update last login date
                user.lastLoginDate = Date()
                try context.save()
                
                // Set session information
                UserDefaults.standard.set(user.email, forKey: "currentUserEmail")
                UserDefaults.standard.set(user.id?.uuidString, forKey: "currentUserID")
                UserDefaults.standard.set(true, forKey: "isLoggedIn")
                
                // Set current user ID in CoreDataManager
                coreDataManager.currentUserID = user.id
                
                print("✅ Authentication successful")
                
                // Log successful login
                AnalyticsManager.shared.logLogin(method: "password", success: true)
                AnalyticsManager.shared.setUserID(user.id?.uuidString ?? "unknown")
                
                return true
            } else {
                print("❌ Authentication failed - invalid password")
                AccountLockoutManager.shared.recordFailedAttempt(email: email)
                
                // Log failed login
                AnalyticsManager.shared.logLogin(method: "password", success: false)
            }
            
        } catch {
            print("❌ Error during authentication: \(error.localizedDescription)")
        }
        
        return false
    }
    
    // MARK: - User Queries
    func userExists(email: String) -> Bool {
        // This method is called from UI before `waitForStoreToLoad` in `createUser`.
        // It defensively returns false if stores aren't loaded, which is generally acceptable
        // for an immediate UI check, as the `createUser` path will wait for store load.
        guard coreDataManager.isStoreLoaded else {
            print("CoreDataManager: Cannot check user existence - stores not loaded yet (UserManager.userExists)")
            return false
        }
        
        let context = CoreDataManager.shared.context
        let fetchRequest: NSFetchRequest<User> = User.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "email == %@", email.lowercased())
        
        do {
            let count = try context.count(for: fetchRequest)
            return count > 0
        } catch {
            print("Error checking if user exists: \(error.localizedDescription)")
            return false
        }
    }
    
    func getCurrentUser() -> User? {
        guard coreDataManager.isStoreLoaded else {
            print("CoreDataManager: Cannot get current user - stores not loaded yet (UserManager.getCurrentUser)")
            return nil
        }
        
        guard let email = UserDefaults.standard.string(forKey: "currentUserEmail") else {
            return nil
        }
        
        let context = CoreDataManager.shared.context
        let fetchRequest: NSFetchRequest<User> = User.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "email == %@ AND isActive == YES", email.lowercased())
        
        do {
            let users = try context.fetch(fetchRequest)
            return users.first
        } catch {
            print("Error fetching current user: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Session Management
    func isUserLoggedIn() -> Bool {
        guard UserDefaults.standard.bool(forKey: "isLoggedIn"),
              let _ = UserDefaults.standard.string(forKey: "currentUserEmail"),
              let userIDString = UserDefaults.standard.string(forKey: "currentUserID"),
              let userID = UUID(uuidString: userIDString) else {
            return false
        }
        
        // Ensure CoreDataManager has the current user ID
        if coreDataManager.currentUserID != userID {
            coreDataManager.currentUserID = userID
        }
        
        return true
    }
    
    func logoutUser() async {
        // Log logout event
        AnalyticsManager.shared.logLogout()
        
        UserDefaults.standard.removeObject(forKey: "currentUserEmail")
        UserDefaults.standard.removeObject(forKey: "currentUserID")
        UserDefaults.standard.set(false, forKey: "isLoggedIn")
        
        // Clear current user ID from CoreDataManager
        coreDataManager.currentUserID = nil
        
        print("User logged out successfully")
    }
    
    // MARK: - Password Helpers
    
    /// Legacy password hashing (kept for migration purposes only)
    private func hashPasswordLegacy(_ password: String) -> String {
        let inputData = Data(password.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    /// Generate a cryptographically secure random salt
    private func generateSalt() -> Data {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        
        guard status == errSecSuccess else {
            // Fallback to less secure but still random salt
            print("Warning: Using fallback salt generation")
            return Data((0..<32).map { _ in UInt8.random(in: 0...255) })
        }
        
        return Data(bytes)
    }
    
    /// Securely hash a password using PBKDF2 with a salt
    /// - Parameters:
    ///   - password: The plaintext password to hash
    ///   - salt: The salt to use (pass nil to generate a new one)
    /// - Returns: A tuple containing the hashed password and the salt used
    private func hashPasswordSecure(_ password: String, salt: Data? = nil) -> (hash: String, salt: Data) {
        let saltData = salt ?? generateSalt()
        let passwordData = Data(password.utf8)
        
        // Use PBKDF2 with 100,000 iterations (industry standard)
        guard let derivedKey = try? PBKDF2.deriveKey(
            password: passwordData,
            salt: saltData,
            iterations: 100_000,
            keyLength: 32
        ) else {
            // Fallback to basic SHA256 if PBKDF2 fails (shouldn't happen)
            print("Warning: PBKDF2 failed, using fallback hashing")
            let combined = saltData + passwordData
            let hash = SHA256.hash(data: combined)
            let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()
            return (hashString, saltData)
        }
        
        return (derivedKey.base64EncodedString(), saltData)
    }
    
    /// Verify a password against a stored hash
    private func verifyPasswordSecure(_ password: String, hash: String, salt: Data) -> Bool {
        let computedHash = hashPasswordSecure(password, salt: salt)
        return computedHash.hash == hash
    }
    
    // MARK: - User Management
    func getAllUsers() -> [User] {
        guard coreDataManager.isStoreLoaded else {
            print("CoreDataManager: Cannot get all users - stores not loaded yet (UserManager.getAllUsers)")
            return []
        }
        
        let context = CoreDataManager.shared.context
        let fetchRequest: NSFetchRequest<User> = User.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdDate", ascending: false)]
        
        do {
            return try context.fetch(fetchRequest)
        } catch {
            print("Error fetching users: \(error.localizedDescription)")
            return []
        }
    }
    
    func deleteUser(email: String) async -> Bool {
        return await withCheckedContinuation { continuation in
            coreDataManager.waitForStoreToLoad { [weak self] success in
                guard let self = self else {
                    continuation.resume(returning: false)
                    return
                }
                
                if !success {
                    continuation.resume(returning: false)
                    return
                }
                
                let result = self.performUserDeletion(email: email)
                continuation.resume(returning: result)
            }
        }
    }
    
    private func performUserDeletion(email: String) -> Bool {
        let context = CoreDataManager.shared.context
        let fetchRequest: NSFetchRequest<User> = User.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "email == %@", email.lowercased())
        
        do {
            let users = try context.fetch(fetchRequest)
            if let user = users.first {
                context.delete(user)
                try context.save()
                print("User \(email) deleted successfully")
                
                // If the deleted user was the one currently logged in, clear session
                if UserDefaults.standard.string(forKey: "currentUserEmail")?.lowercased() == email.lowercased() {
                    Task {
                        await logoutUser()
                    }
                }
                return true
            }
        } catch {
            print("Error deleting user: \(error.localizedDescription)")
        }
        
        return false
    }
    
    func changePassword(email: String, oldPassword: String, newPassword: String) async -> Bool {
        return await withCheckedContinuation { continuation in
            coreDataManager.waitForStoreToLoad { [weak self] success in
                guard let self = self else {
                    continuation.resume(returning: false)
                    return
                }
                
                if !success {
                    continuation.resume(returning: false)
                    return
                }
                
                let result = self.performPasswordChange(email: email, oldPassword: oldPassword, newPassword: newPassword)
                continuation.resume(returning: result)
            }
        }
    }
    
    private func performPasswordChange(email: String, oldPassword: String, newPassword: String) -> Bool {
        let context = CoreDataManager.shared.context
        let fetchRequest: NSFetchRequest<User> = User.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "email == %@ AND isActive == YES", email.lowercased())
        
        do {
            let users = try context.fetch(fetchRequest)
            guard let user = users.first else {
                print("❌ User not found: \(email)")
                return false
            }
            
            var oldPasswordVerified = false
            
            // Verify old password (support both secure and legacy)
            if let storedSalt = user.passwordSalt,
               let storedHash = user.passwordHash {
                // Use secure verification
                oldPasswordVerified = verifyPasswordSecure(oldPassword, hash: storedHash, salt: storedSalt)
            } else {
                // Use legacy verification
                let legacyHash = hashPasswordLegacy(oldPassword)
                oldPasswordVerified = (user.passwordHash == legacyHash)
            }
            
            guard oldPasswordVerified else {
                print("❌ Old password did not match")
                return false
            }
            
            // Set new password with secure hashing
            let (newHash, newSalt) = hashPasswordSecure(newPassword)
            user.passwordHash = newHash
            user.passwordSalt = newSalt
            
            try context.save()
            print("✅ Password changed successfully for \(email) using secure hashing")
            return true
            
        } catch {
            print("❌ Error changing password: \(error.localizedDescription)")
            return false
        }
    }
}

// MARK: - PBKDF2 Key Derivation

/// PBKDF2 Key Derivation for secure password hashing
struct PBKDF2 {
    enum Error: Swift.Error {
        case invalidInput
        case derivationFailed
    }
    
    /// Derive a key using PBKDF2-HMAC-SHA256
    static func deriveKey(
        password: Data,
        salt: Data,
        iterations: Int,
        keyLength: Int
    ) throws -> Data {
        var derivedKeyData = Data(count: keyLength)
        
        let derivationStatus = derivedKeyData.withUnsafeMutableBytes { derivedKeyBytes in
            salt.withUnsafeBytes { saltBytes in
                password.withUnsafeBytes { passwordBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBytes.baseAddress?.assumingMemoryBound(to: Int8.self),
                        password.count,
                        saltBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        UInt32(iterations),
                        derivedKeyBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        keyLength
                    )
                }
            }
        }
        
        guard derivationStatus == kCCSuccess else {
            throw Error.derivationFailed
        }
        
        return derivedKeyData
    }
}
