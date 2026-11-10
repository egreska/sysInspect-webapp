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
        secrets = nil
        context = nil
        container = nil
        super.tearDown()
    }

    private func storedSecret(for user: User) -> SessionSecret? {
        guard let id = user.id else { return nil }
        return secrets.load(userId: id)
    }

    private func makeActiveUser(email: String, password: String) -> User {
        let user = User(context: context)
        user.id = UUID()
        user.email = email.lowercased()
        user.isActive = true
        UserManager.shared.applyPassword(password, to: user)
        return user
    }

    func testApplyPasswordRoundTripsThroughVerify() {
        let user = makeActiveUser(email: "roundtrip@example.com", password: "Secret1a")
        let secret = storedSecret(for: user)
        XCTAssertNil(user.passwordHash)
        XCTAssertNil(user.passwordSalt)
        XCTAssertNotNil(secret?.passwordHash)
        XCTAssertNotNil(secret?.passwordSalt)
        XCTAssertTrue(
            UserManager.shared.verifyPasswordSecure(
                "Secret1a",
                hash: secret!.passwordHash!,
                salt: secret!.passwordSalt!
            )
        )
        XCTAssertFalse(
            UserManager.shared.verifyPasswordSecure(
                "Wrong1a",
                hash: secret!.passwordHash!,
                salt: secret!.passwordSalt!
            )
        )
    }

    func testReplacePasswordWritesHashThatVerifies() {
        _ = makeActiveUser(email: "replace@example.com", password: "OldPass1")
        XCTAssertTrue(
            UserManager.shared.replacePassword(
                email: "replace@example.com",
                newPassword: "NewPass1",
                in: context
            )
        )
        let request: NSFetchRequest<User> = User.fetchRequest()
        request.predicate = NSPredicate(format: "email == %@", "replace@example.com")
        let user = try? context.fetch(request).first
        let secret = user.flatMap { storedSecret(for: $0) }
        XCTAssertNil(user?.passwordHash)
        XCTAssertNotNil(secret?.passwordSalt)
        XCTAssertTrue(
            UserManager.shared.verifyPasswordSecure(
                "NewPass1",
                hash: secret!.passwordHash!,
                salt: secret!.passwordSalt!
            )
        )
        XCTAssertFalse(
            UserManager.shared.verifyPasswordSecure(
                "OldPass1",
                hash: secret!.passwordHash!,
                salt: secret!.passwordSalt!
            )
        )
    }

    func testReplacePasswordFailsForInactiveUser() {
        let user = makeActiveUser(email: "inactive@example.com", password: "Secret1a")
        user.isActive = false
        XCTAssertFalse(
            UserManager.shared.replacePassword(
                email: "inactive@example.com",
                newPassword: "NewPass1",
                in: context
            )
        )
    }

    func testChangePasswordFailsOnWrongOldPassword() {
        _ = makeActiveUser(email: "change@example.com", password: "OldPass1")
        XCTAssertFalse(
            UserManager.shared.changePassword(
                email: "change@example.com",
                oldPassword: "Wrong1a",
                newPassword: "NewPass1",
                in: context
            )
        )
        let request: NSFetchRequest<User> = User.fetchRequest()
        request.predicate = NSPredicate(format: "email == %@", "change@example.com")
        let user = try? context.fetch(request).first
        let secret = user.flatMap { storedSecret(for: $0) }
        XCTAssertTrue(
            UserManager.shared.verifyPasswordSecure(
                "OldPass1",
                hash: secret!.passwordHash!,
                salt: secret!.passwordSalt!
            )
        )
    }

    func testChangePasswordSucceedsOnCorrectOldPassword() {
        _ = makeActiveUser(email: "changeok@example.com", password: "OldPass1")
        XCTAssertTrue(
            UserManager.shared.changePassword(
                email: "changeok@example.com",
                oldPassword: "OldPass1",
                newPassword: "NewPass1",
                in: context
            )
        )
        let request: NSFetchRequest<User> = User.fetchRequest()
        request.predicate = NSPredicate(format: "email == %@", "changeok@example.com")
        let user = try? context.fetch(request).first
        let secret = user.flatMap { storedSecret(for: $0) }
        XCTAssertTrue(
            UserManager.shared.verifyPasswordSecure(
                "NewPass1",
                hash: secret!.passwordHash!,
                salt: secret!.passwordSalt!
            )
        )
    }

    func testVerifyPasswordSucceedsWithoutChangingSession() {
        _ = makeActiveUser(email: "wipe@example.com", password: "Secret1a")
        let previousID = UserManager.shared.sessionUserId
        XCTAssertTrue(
            UserManager.shared.verifyPassword(
                "Secret1a",
                forEmail: "wipe@example.com",
                in: context
            )
        )
        XCTAssertEqual(UserManager.shared.sessionUserId, previousID)
    }

    func testVerifyPasswordFailsWithoutChangingSession() {
        _ = makeActiveUser(email: "wipefail@example.com", password: "Secret1a")
        let previousID = UserManager.shared.sessionUserId
        XCTAssertFalse(
            UserManager.shared.verifyPassword(
                "Wrong1a",
                forEmail: "wipefail@example.com",
                in: context
            )
        )
        XCTAssertEqual(UserManager.shared.sessionUserId, previousID)
    }

    func testLegacySyncedHashMovesIntoTheSecretAndUpgradesOnMatch() {
        let user = User(context: context)
        user.id = UUID()
        user.email = "legacy@example.com"
        user.isActive = true
        let hashed = SHA256.hash(data: Data("Secret1a".utf8))
        user.passwordHash = hashed.compactMap { String(format: "%02x", $0) }.joined()

        XCTAssertEqual(
            UserManager.shared.passwordAvailability(forEmail: "legacy@example.com", in: context),
            .ready
        )
        XCTAssertNil(user.passwordHash)
        XCTAssertTrue(
            UserManager.shared.verifyPassword("Secret1a", forEmail: "legacy@example.com", in: context)
        )
        let secret = storedSecret(for: user)
        XCTAssertEqual(secret?.passwordIterations, SessionSecretRules.iterations)
        XCTAssertNotNil(secret?.passwordSalt)
        XCTAssertNil(user.passwordHash)
    }

    func testMissingSecretWaitsAndDoesNotCountAsAWrongPassword() {
        let user = User(context: context)
        user.id = UUID()
        user.email = "wait@example.com"
        user.isActive = true

        XCTAssertEqual(
            UserManager.shared.passwordAvailability(forEmail: "wait@example.com", in: context),
            .waiting
        )
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
