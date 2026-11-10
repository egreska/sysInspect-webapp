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
    private var defaults: UserDefaults
    private(set) var secrets: SessionSecretStore = KeychainSessionSecretStore()

    private enum SessionKeys {
        static let sessionUserId = "currentUserID"
        static let lastUserId = "lastUserID"
        static let legacyEmail = "currentUserEmail"
        static let legacyLoggedIn = "isLoggedIn"
    }
    
    private init() {
        self.coreDataManager = CoreDataManager.shared
        self.defaults = .standard
        migrateLegacySessionKeysIfNeeded()
        sessionUserId = storedSessionUserId
    }

    private(set) var sessionUserId: UUID?

    var lastUserId: UUID? {
        storedUUID(for: SessionKeys.lastUserId)
    }

    func use(_ defaults: UserDefaults) {
        self.defaults = defaults
        migrateLegacySessionKeysIfNeeded()
        sessionUserId = storedSessionUserId
    }

    func use(secrets: SessionSecretStore) {
        self.secrets = secrets
    }
    
    // MARK: - User Creation
    func createUser(
        email: String,
        password: String,
        securityQuestion: String,
        securityAnswer: String
    ) async -> Bool {
        return await withCheckedContinuation { continuation in
            coreDataManager.waitForStoreToLoad { [weak self] success in
                guard let self else {
                    continuation.resume(returning: false)
                    return
                }
                if !success {
                    print("❌ Error: Core Data stores failed to load")
                    continuation.resume(returning: false)
                    return
                }
                let result = self.performUserCreation(
                    email: email,
                    password: password,
                    securityQuestion: securityQuestion,
                    securityAnswer: securityAnswer
                )
                continuation.resume(returning: result)
            }
        }
    }
    
    private func performUserCreation(
        email: String,
        password: String,
        securityQuestion: String,
        securityAnswer: String
    ) -> Bool {
        let context = CoreDataManager.shared.context
        if userExists(email: email) {
            print("❌ Error creating user: User already exists with this email.")
            return false
        }
        let answer = SessionSecretRules.normalizedAnswer(securityAnswer)
        guard !securityQuestion.isEmpty,
              answer.count >= 8,
              let passwordRecord = hashPasswordSecure(password),
              let answerRecord = hashPasswordSecure(answer) else {
            return false
        }

        let user = User(context: context)
        let userId = UUID()
        user.id = userId
        user.userId = userId
        user.createdDate = Date()
        user.lastLoginDate = Date()
        user.isActive = true
        user.email = email.lowercased()

        var secret = SessionSecret()
        secret.passwordHash = passwordRecord.hash
        secret.passwordSalt = passwordRecord.salt
        secret.passwordIterations = SessionSecretRules.iterations
        secret.securityQuestion = securityQuestion
        secret.securityAnswerHash = answerRecord.hash
        secret.securityAnswerSalt = answerRecord.salt
        secret.securityAnswerIterations = SessionSecretRules.iterations
        guard secrets.save(secret, userId: userId) else {
            context.delete(user)
            return false
        }

        do {
            try context.save()
            AnalyticsManager.shared.logAccountCreated()
            startSession(userId: userId)
            return true
        } catch {
            secrets.delete(userId: userId)
            context.delete(user)
            print("❌ Error creating user: \(error)")
            return false
        }
    }

    
    // MARK: - User Authentication
    func authenticateUser(email: String, password: String) async -> LoginResult {
        // Ensure Core Data stores are loaded first
        return await withCheckedContinuation { continuation in
            coreDataManager.waitForStoreToLoad { [weak self] success in
                guard let self else {
                    continuation.resume(returning: .failure)
                    return
                }
                if !success {
                    print("❌ Error: Core Data stores failed to load")
                    continuation.resume(returning: .failure)
                    return
                }
                continuation.resume(returning: self.performAuthentication(email: email, password: password))
            }
        }
    }
    
    private func performAuthentication(email: String, password: String) -> LoginResult {
        if AccountLockoutManager.shared.isAccountLocked(email: email) {
            return .failure
        }

        let context = CoreDataManager.shared.context
        let fetchRequest: NSFetchRequest<User> = User.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "email == %@ AND isActive == YES", email.lowercased())

        do {
            guard let user = try context.fetch(fetchRequest).first else {
                AccountLockoutManager.shared.recordFailedAttempt(email: email)
                return .failure
            }
            absorbSyncedSecrets(for: user, defaults: defaults, in: context)
            guard let userId = user.id,
                  secrets.load(userId: userId)?.hasPassword == true else {
                return .waiting
            }
            guard passwordMatches(password, user: user, in: context) else {
                AccountLockoutManager.shared.recordFailedAttempt(email: email)
                AnalyticsManager.shared.logLogin(method: "password", success: false)
                return .failure
            }

            AccountLockoutManager.shared.recordSuccessfulLogin(email: email)
            user.lastLoginDate = Date()
            try context.save()
            startSession(userId: userId)
            AnalyticsManager.shared.logLogin(method: "password", success: true)
            AnalyticsManager.shared.setUserID(userId.uuidString)
            return .success
        } catch {
            print("❌ Error during authentication: \(error.localizedDescription)")
            return .failure
        }
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
        guard let id = sessionUserId ?? storedSessionUserId else {
            return nil
        }
        return fetchActiveUser(id: id, in: CoreDataManager.shared.context)
    }
    
    // MARK: - Session Management
    func startSession(userId: UUID) {
        sessionUserId = userId
        defaults.set(userId.uuidString, forKey: SessionKeys.sessionUserId)
        defaults.set(userId.uuidString, forKey: SessionKeys.lastUserId)
    }

    func clearSession() {
        sessionUserId = nil
        defaults.removeObject(forKey: SessionKeys.sessionUserId)
    }

    func wipeSession() {
        clearSession()
        defaults.removeObject(forKey: SessionKeys.lastUserId)
    }

    func isUserLoggedIn() -> Bool {
        migrateLegacySessionKeysIfNeeded()
        guard let id = storedSessionUserId else {
            sessionUserId = nil
            return false
        }
        sessionUserId = id
        return true
    }
    
    func logoutUser() async {
        AnalyticsManager.shared.logLogout()
        clearSession()
        print("User logged out successfully")
    }

    func completeBiometricLogin() -> Bool {
        guard let lastId = lastUserId,
              let user = fetchActiveUser(id: lastId, in: CoreDataManager.shared.context),
              let userId = user.id else {
            return false
        }
        startSession(userId: userId)
        user.lastLoginDate = Date()
        _ = CoreDataManager.shared.saveContext()
        return true
    }

    func verifyCurrentUserPassword(_ password: String) async -> Bool {
        await withCheckedContinuation { continuation in
            coreDataManager.waitForStoreToLoad { [weak self] success in
                guard let self, success,
                      let user = self.getCurrentUser(),
                      let email = user.email else {
                    continuation.resume(returning: false)
                    return
                }
                continuation.resume(returning: self.verifyPassword(
                    password,
                    forEmail: email,
                    in: CoreDataManager.shared.context
                ))
            }
        }
    }

    private var storedSessionUserId: UUID? {
        storedUUID(for: SessionKeys.sessionUserId)
    }

    private func storedUUID(for key: String) -> UUID? {
        guard let raw = defaults.string(forKey: key) else { return nil }
        return UUID(uuidString: raw)
    }

    private func migrateLegacySessionKeysIfNeeded() {
        if defaults.string(forKey: SessionKeys.lastUserId) == nil,
           let session = defaults.string(forKey: SessionKeys.sessionUserId) {
            defaults.set(session, forKey: SessionKeys.lastUserId)
        }
        defaults.removeObject(forKey: SessionKeys.legacyLoggedIn)
        defaults.removeObject(forKey: SessionKeys.legacyEmail)
    }

    private func fetchActiveUser(id: UUID, in context: NSManagedObjectContext) -> User? {
        let fetchRequest: NSFetchRequest<User> = User.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@ AND isActive == YES", id as CVarArg)
        fetchRequest.fetchLimit = 1
        return try? context.fetch(fetchRequest).first
    }

    func verifyPassword(_ password: String, forEmail email: String, in context: NSManagedObjectContext) -> Bool {
        let fetchRequest: NSFetchRequest<User> = User.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "email == %@ AND isActive == YES", email.lowercased())
        guard let user = try? context.fetch(fetchRequest).first else { return false }
        return passwordMatches(password, user: user, in: context)
    }

    func passwordAvailability(forEmail email: String, in context: NSManagedObjectContext) -> PasswordAvailability {
        let fetchRequest: NSFetchRequest<User> = User.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "email == %@ AND isActive == YES", email.lowercased())
        fetchRequest.fetchLimit = 1
        guard let user = try? context.fetch(fetchRequest).first else { return .noUser }
        absorbSyncedSecrets(for: user, defaults: defaults, in: context)
        guard let userId = user.id, secrets.load(userId: userId)?.hasPassword == true else {
            return .waiting
        }
        return .ready
    }

    func absorbSyncedSecrets(for user: User, defaults: UserDefaults, in context: NSManagedObjectContext) {
        guard let userId = user.id else { return }
        var secret = secrets.load(userId: userId) ?? SessionSecret()
        var dirty = false
        if secret.passwordHash == nil, let hash = user.passwordHash {
            secret.passwordHash = hash
            secret.passwordSalt = user.passwordSalt
            secret.passwordIterations = user.passwordSalt == nil ? nil : SessionSecretRules.iterations
            dirty = true
        }
        if !secret.hasSecurityAnswer {
            if let hash = user.securityAnswerHash {
                secret.securityQuestion = user.securityQuestion
                secret.securityAnswerHash = hash
                secret.securityAnswerSalt = user.securityAnswerSalt
                secret.securityAnswerIterations = user.securityAnswerSalt == nil ? nil : SessionSecretRules.iterations
                dirty = true
            } else if let email = user.email?.lowercased(),
                      let hash = defaults.string(forKey: "securityAnswer_\(email)") {
                secret.securityQuestion = defaults.string(forKey: "securityQuestion_\(email)")
                secret.securityAnswerHash = hash
                secret.securityAnswerSalt = defaults.data(forKey: "securityAnswerSalt_\(email)")
                secret.securityAnswerIterations = secret.securityAnswerSalt == nil ? nil : SessionSecretRules.iterations
                dirty = true
            }
        }
        if dirty, !secrets.save(secret, userId: userId) {
            return
        }
        let hadColumns = user.passwordHash != nil
            || user.passwordSalt != nil
            || user.securityQuestion != nil
            || user.securityAnswerHash != nil
            || user.securityAnswerSalt != nil
        if hadColumns {
            user.passwordHash = nil
            user.passwordSalt = nil
            user.securityQuestion = nil
            user.securityAnswerHash = nil
            user.securityAnswerSalt = nil
            try? context.save()
        }
        if let email = user.email?.lowercased() {
            defaults.removeObject(forKey: "securityQuestion_\(email)")
            defaults.removeObject(forKey: "securityAnswer_\(email)")
            defaults.removeObject(forKey: "securityAnswerSalt_\(email)")
        }
    }
    
    // MARK: - Password Helpers

    private func hashPasswordLegacy(_ password: String) -> String {
        let hashed = SHA256.hash(data: Data(password.utf8))
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }

    private func generateSalt() -> Data? {
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            return nil
        }
        return Data(bytes)
    }

    func hashPasswordSecure(_ password: String, salt: Data? = nil) -> (hash: String, salt: Data)? {
        guard let saltData = salt ?? generateSalt() else { return nil }
        guard let derivedKey = try? PBKDF2.deriveKey(
            password: Data(password.utf8),
            salt: saltData,
            iterations: SessionSecretRules.iterations,
            keyLength: 32
        ) else {
            return nil
        }
        return (derivedKey.base64EncodedString(), saltData)
    }
    
    @discardableResult
    func applyPassword(_ password: String, to user: User) -> Bool {
        guard let userId = user.id else { return false }
        let existing = secrets.load(userId: userId) ?? SessionSecret()
        guard storePassword(password, userId: userId, preserving: existing) else { return false }
        user.passwordHash = nil
        user.passwordSalt = nil
        return true
    }

    func verifyPasswordSecure(
        _ password: String,
        hash: String,
        salt: Data,
        iterations: Int = SessionSecretRules.iterations
    ) -> Bool {
        guard let derivedKey = try? PBKDF2.deriveKey(
            password: Data(password.utf8),
            salt: salt,
            iterations: iterations,
            keyLength: 32
        ) else {
            return false
        }
        return hashesMatch(derivedKey.base64EncodedString(), hash)
    }

    func passwordMatches(_ password: String, user: User, in context: NSManagedObjectContext) -> Bool {
        absorbSyncedSecrets(for: user, defaults: defaults, in: context)
        guard let userId = user.id,
              let secret = secrets.load(userId: userId),
              let storedHash = secret.passwordHash else {
            return false
        }
        let matches: Bool
        if let salt = secret.passwordSalt, let iterations = secret.passwordIterations {
            matches = verifyPasswordSecure(password, hash: storedHash, salt: salt, iterations: iterations)
        } else {
            matches = hashesMatch(storedHash, hashPasswordLegacy(password))
        }
        if matches, secret.passwordIterations == nil {
            _ = storePassword(password, userId: userId, preserving: secret)
        }
        return matches
    }

    private func storePassword(_ password: String, userId: UUID, preserving secret: SessionSecret) -> Bool {
        guard let record = hashPasswordSecure(password) else { return false }
        var updated = secret
        updated.passwordHash = record.hash
        updated.passwordSalt = record.salt
        updated.passwordIterations = SessionSecretRules.iterations
        return secrets.save(updated, userId: userId)
    }

    func hashesMatch(_ lhs: String, _ rhs: String) -> Bool {
        let left = Array(lhs.utf8)
        let right = Array(rhs.utf8)
        guard left.count == right.count else { return false }
        var difference: UInt8 = 0
        for index in left.indices {
            difference |= left[index] ^ right[index]
        }
        return difference == 0
    }
    
    func replacePassword(email: String, newPassword: String) async -> Bool {
        await withCheckedContinuation { continuation in
            coreDataManager.waitForStoreToLoad { [weak self] success in
                guard let self else {
                    continuation.resume(returning: false)
                    return
                }
                if !success {
                    continuation.resume(returning: false)
                    return
                }
                continuation.resume(returning: self.replacePassword(
                    email: email,
                    newPassword: newPassword,
                    in: CoreDataManager.shared.context
                ))
            }
        }
    }

    func replacePassword(email: String, newPassword: String, in context: NSManagedObjectContext) -> Bool {
        let fetchRequest: NSFetchRequest<User> = User.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "email == %@ AND isActive == YES", email.lowercased())
        do {
            guard let user = try context.fetch(fetchRequest).first else {
                print("❌ User not found: \(email)")
                return false
            }
            guard applyPassword(newPassword, to: user) else { return false }
            try context.save()
            return true
        } catch {
            print("❌ Error replacing password: \(error.localizedDescription)")
            return false
        }
    }

    func changePassword(email: String, oldPassword: String, newPassword: String) async -> Bool {
        return await withCheckedContinuation { continuation in
            coreDataManager.waitForStoreToLoad { [weak self] success in
                guard let self else {
                    continuation.resume(returning: false)
                    return
                }
                if !success {
                    continuation.resume(returning: false)
                    return
                }
                continuation.resume(returning: self.changePassword(
                    email: email,
                    oldPassword: oldPassword,
                    newPassword: newPassword,
                    in: CoreDataManager.shared.context
                ))
            }
        }
    }

    func changePassword(email: String, oldPassword: String, newPassword: String, in context: NSManagedObjectContext) -> Bool {
        let fetchRequest: NSFetchRequest<User> = User.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "email == %@ AND isActive == YES", email.lowercased())
        do {
            let users = try context.fetch(fetchRequest)
            guard let user = users.first else {
                print("❌ User not found: \(email)")
                return false
            }
            guard passwordMatches(oldPassword, user: user, in: context) else {
                return false
            }
            guard applyPassword(newPassword, to: user) else { return false }
            try context.save()
            return true
        } catch {
            print("❌ Error changing password: \(error.localizedDescription)")
            return false
        }
    }
}

enum LoginResult: Equatable {
    case success
    case failure
    case waiting
}

enum PasswordAvailability: Equatable {
    case noUser
    case waiting
    case ready
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
