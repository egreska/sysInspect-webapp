//
//  UserManagerPasswordTests.swift
//  Systems InspectorTests
//

import CoreData
import XCTest
@testable import Systems_Inspector

final class UserManagerPasswordTests: XCTestCase {

    var container: NSPersistentContainer!
    var context: NSManagedObjectContext!

    override func setUp() {
        super.setUp()
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
        context = nil
        container = nil
        super.tearDown()
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
        XCTAssertNotNil(user.passwordHash)
        XCTAssertNotNil(user.passwordSalt)
        XCTAssertTrue(
            UserManager.shared.verifyPasswordSecure(
                "Secret1a",
                hash: user.passwordHash!,
                salt: user.passwordSalt!
            )
        )
        XCTAssertFalse(
            UserManager.shared.verifyPasswordSecure(
                "Wrong1a",
                hash: user.passwordHash!,
                salt: user.passwordSalt!
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
        XCTAssertNotNil(user?.passwordSalt)
        XCTAssertTrue(
            UserManager.shared.verifyPasswordSecure(
                "NewPass1",
                hash: user!.passwordHash!,
                salt: user!.passwordSalt!
            )
        )
        XCTAssertFalse(
            UserManager.shared.verifyPasswordSecure(
                "OldPass1",
                hash: user!.passwordHash!,
                salt: user!.passwordSalt!
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
        XCTAssertTrue(
            UserManager.shared.verifyPasswordSecure(
                "OldPass1",
                hash: user!.passwordHash!,
                salt: user!.passwordSalt!
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
        XCTAssertTrue(
            UserManager.shared.verifyPasswordSecure(
                "NewPass1",
                hash: user!.passwordHash!,
                salt: user!.passwordSalt!
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
}
