//
//  UserManagerPasswordTests.swift
//  Systems InspectorTests
//

import CoreData
import CryptoKit
import XCTest
@testable import Systems_Inspector

final class UserManagerPasswordTests: XCTestCase {

    var container: NSPersistentContainer!
    var context: NSManagedObjectContext!
    var secrets: MemorySessionSecretStore!

    override func setUp() {
        super.setUp()
        secrets = MemorySessionSecretStore()
        UserManager.shared.use(secrets: secrets)
        guard let model = NSManagedObjectModel.mergedModel(from: [Bundle(for: CoreDataManager.self)]) else {
            XCTFail("Missing Core Data model")
            return
        }
        container = NSPersistentContainer(name: "Systems_Inspector", managedObjectModel: model)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        description.shouldAddStoreAsynchronously = false
        container.persistentStoreDescriptions = [description]
        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
        }
        XCTAssertNil(loadError, "In-memory store failed to load: \(String(describing: loadError))")
        context = container.viewContext
    }

    override func tearDown() {
        UserManager.shared.use(secrets: KeychainSessionSecretStore())
        secrets = nil
        context = nil
        container = nil
        super.tearDown()
    }

    private func storedSecret(for user: User) -> SessionSecret? {
        guard let id = user.id else { return nil }
        return secrets.load(userId: id)
    }

    private func makeActiveUser(email: String) -> User {
        let user = User(context: context)
        user.id = UUID()
        user.email = email.lowercased()
        user.isActive = true
        return user
    }

    func testReplacePasswordOffMainRoundTripsThroughCheckPassword() async {
        let user = makeActiveUser(email: "roundtrip@example.com")
        let wrote = await UserManager.shared.replacePasswordOffMain(
            email: "roundtrip@example.com",
            newPassword: "Secret1a",
            in: context
        )
        XCTAssertTrue(wrote)
        let secret = storedSecret(for: user)
        XCTAssertNil(user.passwordHash)
        XCTAssertNil(user.passwordSalt)
        XCTAssertNotNil(secret?.passwordHash)
        XCTAssertNotNil(secret?.passwordSalt)
        let match = await UserManager.shared.checkPassword("Secret1a", forEmail: "roundtrip@example.com", in: context)
        guard case .match = match else {
            return XCTFail("Expected a match")
        }
        let miss = await UserManager.shared.checkPassword("Wrong1a", forEmail: "roundtrip@example.com", in: context)
        guard case .mismatch = miss else {
            return XCTFail("Expected a mismatch")
        }
    }

    func testReplacePasswordOffMainReplacesTheHash() async {
        _ = makeActiveUser(email: "replace@example.com")
        let first = await UserManager.shared.replacePasswordOffMain(
            email: "replace@example.com",
            newPassword: "OldPass1",
            in: context
        )
        XCTAssertTrue(first)
        let second = await UserManager.shared.replacePasswordOffMain(
            email: "replace@example.com",
            newPassword: "NewPass1",
            in: context
        )
        XCTAssertTrue(second)
        let match = await UserManager.shared.checkPassword("NewPass1", forEmail: "replace@example.com", in: context)
        guard case .match = match else {
            return XCTFail("Expected the new password to match")
        }
        let old = await UserManager.shared.checkPassword("OldPass1", forEmail: "replace@example.com", in: context)
        guard case .mismatch = old else {
            return XCTFail("Expected the old password to miss")
        }
    }

    func testReplacePasswordOffMainFailsForInactiveUser() async {
        let user = makeActiveUser(email: "inactive@example.com")
        let first = await UserManager.shared.replacePasswordOffMain(
            email: "inactive@example.com",
            newPassword: "Secret1a",
            in: context
        )
        XCTAssertTrue(first)
        let before = storedSecret(for: user)?.passwordHash
        user.isActive = false
        let second = await UserManager.shared.replacePasswordOffMain(
            email: "inactive@example.com",
            newPassword: "NewPass1",
            in: context
        )
        XCTAssertFalse(second)
        XCTAssertEqual(storedSecret(for: user)?.passwordHash, before)
    }

    func testCheckPasswordDoesNotChangeTheSession() async {
        _ = makeActiveUser(email: "wipe@example.com")
        let wrote = await UserManager.shared.replacePasswordOffMain(
            email: "wipe@example.com",
            newPassword: "Secret1a",
            in: context
        )
        XCTAssertTrue(wrote)
        let previousID = UserManager.shared.sessionUserId
        let match = await UserManager.shared.checkPassword("Secret1a", forEmail: "wipe@example.com", in: context)
        guard case .match = match else {
            return XCTFail("Expected a match")
        }
        XCTAssertEqual(UserManager.shared.sessionUserId, previousID)
        let miss = await UserManager.shared.checkPassword("Wrong1a", forEmail: "wipefail@example.com", in: context)
        guard case .absent = miss else {
            return XCTFail("Expected an absent user")
        }
        XCTAssertEqual(UserManager.shared.sessionUserId, previousID)
    }

    func testLegacySyncedHashMovesIntoTheSecretAndUpgradesOnMatch() async {
        let user = makeActiveUser(email: "legacy@example.com")
        let hashed = SHA256.hash(data: Data("Secret1a".utf8))
        user.passwordHash = hashed.compactMap { String(format: "%02x", $0) }.joined()

        let match = await UserManager.shared.checkPassword("Secret1a", forEmail: "legacy@example.com", in: context)
        guard case .match = match else {
            return XCTFail("Expected a match")
        }
        let secret = storedSecret(for: user)
        XCTAssertEqual(secret?.passwordIterations, SessionSecretRules.iterations)
        XCTAssertNotNil(secret?.passwordSalt)
        XCTAssertNil(user.passwordHash)
    }

    func testMissingSecretWaitsAndDoesNotCountAsAWrongPassword() async {
        _ = makeActiveUser(email: "wait@example.com")
        let outcome = await UserManager.shared.checkPassword("Secret1a", forEmail: "wait@example.com", in: context)
        guard case .waiting = outcome else {
            return XCTFail("Expected waiting")
        }
        XCTAssertEqual(AccountLockoutManager.shared.getFailedAttempts(email: "wait@example.com"), 0)
    }

    func testKeychainStoreRoundTripsASynchronizedSecret() {
        let store = KeychainSessionSecretStore()
        let userId = UUID()
        defer { store.delete(userId: userId) }
        var secret = SessionSecret()
        secret.passwordHash = "hash"
        secret.passwordIterations = SessionSecretRules.iterations
        secret.securityQuestion = "What city were you born in?"
        secret.securityAnswerHash = "answer"
        XCTAssertTrue(store.save(secret, userId: userId))
        XCTAssertEqual(store.load(userId: userId), secret)
        secret.passwordHash = "replaced"
        XCTAssertTrue(store.save(secret, userId: userId))
        XCTAssertEqual(store.load(userId: userId)?.passwordHash, "replaced")
        store.delete(userId: userId)
        XCTAssertNil(store.load(userId: userId))
    }
}
