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
        guard await waitUntilStoreLoaded() else {
            #if DEBUG
            print("❌ Error: Core Data stores failed to load")
            #endif
            return false
        }
        return await performUserCreationOffMain(
            email: email,
            password: password,
            securityQuestion: securityQuestion,
            securityAnswer: securityAnswer,
            in: coreDataManager.context
        )
    }

    func performUserCreationOffMain(
        email: String,
        password: String,
        securityQuestion: String,
        securityAnswer: String,
        in context: NSManagedObjectContext
    ) async -> Bool {
        let prelude = context.performAndWait {
            self.creationPrelude(
                email: email,
                password: password,
                securityQuestion: securityQuestion,
                securityAnswer: securityAnswer,
                in: context
            )
        }
        guard case .ready(let answer) = prelude else { return false }
        async let passwordRecord = hashPasswordSecureOffMain(password)
        async let answerRecord = hashPasswordSecureOffMain(answer)
        guard let passwordRecord = await passwordRecord,
              let answerRecord = await answerRecord else {
            return false
        }
        return context.performAndWait {
            self.insertCreatedUser(
                email: email,
                securityQuestion: securityQuestion,
                password: passwordRecord,
                answer: answerRecord,
                in: context
            )
        }
    }

    private enum CreationPrelude {
        case refused
        case ready(answer: String)
    }

    private func creationPrelude(
        email: String,
        password: String,
        securityQuestion: String,
        securityAnswer: String,
        in context: NSManagedObjectContext
    ) -> CreationPrelude {
        if userExists(email: email, in: context) {
            #if DEBUG
            print("❌ Error creating user: User already exists with this email.")
            #endif
            return .refused
        }
        guard PasswordRecoveryManager.shared.validatePasswordStrength(password).isValid else {
            return .refused
        }
        let answer = SessionSecretRules.normalizedAnswer(securityAnswer)
        guard !securityQuestion.isEmpty, answer.count >= 8 else { return .refused }
        return .ready(answer: answer)
    }

    private func insertCreatedUser(
        email: String,
        securityQuestion: String,
        password passwordRecord: (hash: String, salt: Data),
        answer answerRecord: (hash: String, salt: Data),
        in context: NSManagedObjectContext
    ) -> Bool {
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
            #if DEBUG
            print("❌ Error creating user: \(error)")
            #endif
            return false
        }
    }

    private func waitUntilStoreLoaded() async -> Bool {
        await withCheckedContinuation { continuation in
            coreDataManager.waitForStoreToLoad { ready in
                continuation.resume(returning: ready)
            }
        }
    }

    
    // MARK: - User Authentication
    func authenticateUser(email: String, password: String) async -> LoginResult {
        guard await waitUntilStoreLoaded() else {
            #if DEBUG
            print("❌ Error: Core Data stores failed to load")
            #endif
            return .failure
        }
        return await performAuthentication(email: email, password: password)
    }

    private func performAuthentication(email: String, password: String) async -> LoginResult {
        if AccountLockoutManager.shared.isAccountLocked(email: email) {
            return .failure
        }

        let context = coreDataManager.context
        let gate = context.performAndWait {
            self.loginGate(email: email, in: context)
        }
        switch gate {
        case .noUser:
            AccountLockoutManager.shared.recordFailedAttempt(email: email)
            return .failure
        case .waiting:
            return .waiting
        case .ready(let userID, let hash, let salt, let iterations):
            let matches = await passwordIsValid(password, hash: hash, salt: salt, iterations: iterations)
            guard matches else {
                AccountLockoutManager.shared.recordFailedAttempt(email: email)
                AnalyticsManager.shared.logLogin(method: "password", success: false)
                return .failure
            }
            if iterations == nil {
                await upgradeLegacyPassword(password, userID: userID, in: context)
            }
            return context.performAndWait {
                guard let user = self.fetchActiveUser(id: userID, in: context) else { return LoginResult.failure }
                AccountLockoutManager.shared.recordSuccessfulLogin(email: email)
                user.lastLoginDate = Date()
                do {
                    try context.save()
                } catch {
                    #if DEBUG
                    print("❌ Error during authentication: \(error.localizedDescription)")
                    #endif
                    return .failure
                }
                self.startSession(userId: userID)
                AnalyticsManager.shared.logLogin(method: "password", success: true)
                AnalyticsManager.shared.setUserID(userID.uuidString)
                return .success
            }
        }
    }

    private enum LoginGate {
        case noUser
        case waiting
        case ready(userID: UUID, hash: String, salt: Data?, iterations: Int?)
    }

    private func loginGate(email: String, in context: NSManagedObjectContext) -> LoginGate {
        let fetchRequest: NSFetchRequest<User> = User.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "email == %@ AND isActive == YES", email.lowercased())
        guard let user = try? context.fetch(fetchRequest).first else { return .noUser }
        absorbSyncedSecrets(for: user, defaults: defaults, in: context)
        guard let userId = user.id,
              let secret = secrets.load(userId: userId),
              secret.hasPassword,
              let hash = secret.passwordHash else {
            return .waiting
        }
        return .ready(userID: userId, hash: hash, salt: secret.passwordSalt, iterations: secret.passwordIterations)
    }

    private func passwordIsValid(
        _ password: String,
        hash: String,
        salt: Data?,
        iterations: Int?
    ) async -> Bool {
        if let salt, let iterations {
            return await verifyPasswordSecureOffMain(password, hash: hash, salt: salt, iterations: iterations)
        }
        return hashesMatch(hash, hashPasswordLegacy(password))
    }

    private func upgradeLegacyPassword(
        _ password: String,
        userID: UUID,
        in context: NSManagedObjectContext
    ) async {
        guard let record = await hashPasswordSecureOffMain(password) else { return }
        context.performAndWait {
            let existing = self.secrets.load(userId: userID) ?? SessionSecret()
            _ = self.storeDerivedPassword(record, userId: userID, preserving: existing)
        }
    }
    
    // MARK: - User Queries
    func userExists(email: String) -> Bool {
        guard coreDataManager.isStoreLoaded else {
            #if DEBUG
            print("CoreDataManager: Cannot check user existence - stores not loaded yet (UserManager.userExists)")
            #endif
            return false
        }
        return userExists(email: email, in: CoreDataManager.shared.context)
    }

    func userExists(email: String, in context: NSManagedObjectContext) -> Bool {
        let fetchRequest: NSFetchRequest<User> = User.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "email == %@", email.lowercased())
        do {
            let count = try context.count(for: fetchRequest)
            return count > 0
        } catch {
            #if DEBUG
            print("Error checking if user exists: \(error.localizedDescription)")
            #endif
            return false
        }
    }
    
    func getCurrentUser() -> User? {
        guard coreDataManager.isStoreLoaded else {
            #if DEBUG
            print("CoreDataManager: Cannot get current user - stores not loaded yet (UserManager.getCurrentUser)")
            #endif
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
        if let userId = sessionUserId {
            CustomerSearchIndex.removeSession(userId: userId)
        }
        clearSession()
        #if DEBUG
        print("User logged out successfully")
        #endif
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
        guard await waitUntilStoreLoaded() else { return false }
        let context = coreDataManager.context
        let material: (userID: UUID, hash: String, salt: Data?, iterations: Int?)? = context.performAndWait {
            guard let user = self.getCurrentUser(), let email = user.email else { return nil }
            guard case .ready(let userID, let hash, let salt, let iterations) = self.loginGate(email: email, in: context) else {
                return nil
            }
            return (userID, hash, salt, iterations)
        }
        guard let material else { return false }
        let matches = await passwordIsValid(
            password,
            hash: material.hash,
            salt: material.salt,
            iterations: material.iterations
        )
        if matches, material.iterations == nil {
            await upgradeLegacyPassword(password, userID: material.userID, in: context)
        }
        return matches
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

    func hashPasswordSecureOffMain(_ password: String, salt: Data? = nil) async -> (hash: String, salt: Data)? {
        guard let saltData = salt ?? generateSalt() else { return nil }
        guard let derivedKey = await PBKDF2.deriveKeyOffMain(
            password: Data(password.utf8),
            salt: saltData,
            iterations: SessionSecretRules.iterations,
            keyLength: 32
        ) else {
            return nil
        }
        return (derivedKey.base64EncodedString(), saltData)
    }

    func verifyPasswordSecureOffMain(
        _ password: String,
        hash: String,
        salt: Data,
        iterations: Int = SessionSecretRules.iterations
    ) async -> Bool {
        guard let derivedKey = await PBKDF2.deriveKeyOffMain(
            password: Data(password.utf8),
            salt: salt,
            iterations: iterations,
            keyLength: 32
        ) else {
            return false
        }
        return hashesMatch(derivedKey.base64EncodedString(), hash)
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
        return storeDerivedPassword(record, userId: userId, preserving: secret)
    }

    private func storeDerivedPassword(
        _ record: (hash: String, salt: Data),
        userId: UUID,
        preserving secret: SessionSecret
    ) -> Bool {
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
        guard await waitUntilStoreLoaded() else { return false }
        return await replacePasswordOffMain(
            email: email,
            newPassword: newPassword,
            in: coreDataManager.context
        )
    }

    func replacePasswordOffMain(
        email: String,
        newPassword: String,
        in context: NSManagedObjectContext
    ) async -> Bool {
        guard let record = await hashPasswordSecureOffMain(newPassword) else { return false }
        return context.performAndWait {
            let fetchRequest: NSFetchRequest<User> = User.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "email == %@ AND isActive == YES", email.lowercased())
            do {
                guard let user = try context.fetch(fetchRequest).first else {
                    #if DEBUG
                    print("❌ User not found: \(email)")
                    #endif
                    return false
                }
                guard self.writeDerivedPassword(record, to: user) else { return false }
                try context.save()
                return true
            } catch {
                #if DEBUG
                print("❌ Error replacing password: \(error.localizedDescription)")
                #endif
                return false
            }
        }
    }

    private func writeDerivedPassword(_ record: (hash: String, salt: Data), to user: User) -> Bool {
        guard let userId = user.id else { return false }
        let existing = secrets.load(userId: userId) ?? SessionSecret()
        guard storeDerivedPassword(record, userId: userId, preserving: existing) else { return false }
        user.passwordHash = nil
        user.passwordSalt = nil
        return true
    }

    func replacePassword(email: String, newPassword: String, in context: NSManagedObjectContext) -> Bool {
        let fetchRequest: NSFetchRequest<User> = User.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "email == %@ AND isActive == YES", email.lowercased())
        do {
            guard let user = try context.fetch(fetchRequest).first else {
                #if DEBUG
                print("❌ User not found: \(email)")
                #endif
                return false
            }
            guard applyPassword(newPassword, to: user) else { return false }
            try context.save()
            return true
        } catch {
            #if DEBUG
            print("❌ Error replacing password: \(error.localizedDescription)")
            #endif
            return false
        }
    }

    func changePassword(email: String, oldPassword: String, newPassword: String) async -> Bool {
        guard await waitUntilStoreLoaded() else { return false }
        let context = coreDataManager.context
        let gate = context.performAndWait {
            self.loginGate(email: email, in: context)
        }
        guard case .ready(let userID, let hash, let salt, let iterations) = gate else { return false }
        let matches = await passwordIsValid(oldPassword, hash: hash, salt: salt, iterations: iterations)
        guard matches else { return false }
        if iterations == nil {
            await upgradeLegacyPassword(oldPassword, userID: userID, in: context)
        }
        return await replacePasswordOffMain(email: email, newPassword: newPassword, in: context)
    }

    func changePassword(email: String, oldPassword: String, newPassword: String, in context: NSManagedObjectContext) -> Bool {
        let fetchRequest: NSFetchRequest<User> = User.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "email == %@ AND isActive == YES", email.lowercased())
        do {
            let users = try context.fetch(fetchRequest)
            guard let user = users.first else {
                #if DEBUG
                print("❌ User not found: \(email)")
                #endif
                return false
            }
            guard passwordMatches(oldPassword, user: user, in: context) else {
                return false
            }
            guard applyPassword(newPassword, to: user) else { return false }
            try context.save()
            return true
        } catch {
            #if DEBUG
            print("❌ Error changing password: \(error.localizedDescription)")
            #endif
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

    static func deriveKeyOffMain(
        password: Data,
        salt: Data,
        iterations: Int,
        keyLength: Int
    ) async -> Data? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: try? deriveKey(
                    password: password,
                    salt: salt,
                    iterations: iterations,
                    keyLength: keyLength
                ))
            }
        }
    }
}
