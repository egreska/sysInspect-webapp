//
//  SessionOpeningTests.swift
//  Systems InspectorTests
//

import CoreData
import CryptoKit
import XCTest
@testable import Systems_Inspector

@MainActor
final class SessionOpeningTests: XCTestCase {
    private var container: NSPersistentContainer!
    private var defaults: SessionTestDefaults!
    private let question = "What was the name of your first pet?"
    private let answer = "Fluffy12"
    private let password = "Password123"

    override func setUp() async throws {
        try await super.setUp()
        UserManager.shared.use(secrets: MemorySessionSecretStore())
        defaults = SessionTestDefaults()
        defaults.install()
    }

    override func tearDown() async throws {
        defaults?.uninstall()
        UserManager.shared.use(secrets: KeychainSessionSecretStore())
        container = nil
        try await super.tearDown()
    }

    func testStartRefusesAShortPassword() async throws {
        let (context, opening) = try makeOpening()
        let outcome = await opening.start(
            email: freshEmail("short"),
            password: "Pass1",
            securityQuestion: question,
            securityAnswer: answer
        )
        guard case .refused(let notice) = outcome else {
            return XCTFail("Expected a refusal")
        }
        XCTAssertEqual(notice.title, "Weak Password")
        XCTAssertTrue(notice.message.contains("8 characters"))
        XCTAssertEqual(try context.count(for: User.fetchRequest()), 0)
        XCTAssertNil(UserManager.shared.sessionUserId)
    }

    func testStartRefusesAPasswordWithoutUppercase() async throws {
        try await assertPasswordRefusal("password123", fragment: "uppercase")
    }

    func testStartRefusesAPasswordWithoutLowercase() async throws {
        try await assertPasswordRefusal("PASSWORD123", fragment: "lowercase")
    }

    func testStartRefusesAPasswordWithoutANumber() async throws {
        try await assertPasswordRefusal("PasswordOnly", fragment: "number")
    }

    func testStartRefusesAShortSecurityAnswer() async throws {
        let (context, opening) = try makeOpening()
        let outcome = await opening.start(
            email: freshEmail("answer"),
            password: password,
            securityQuestion: question,
            securityAnswer: "  fluffy  "
        )
        guard case .refused(let notice) = outcome else {
            return XCTFail("Expected a refusal")
        }
        XCTAssertEqual(notice.title, "Error")
        XCTAssertTrue(notice.message.contains("8 characters"))
        XCTAssertEqual(try context.count(for: User.fetchRequest()), 0)
        XCTAssertNil(UserManager.shared.sessionUserId)
    }

    func testStartRefusesAnEmailThatAlreadyHasASession() async throws {
        let email = freshEmail("taken")
        let (context, opening) = try makeOpening()
        let first = await opening.start(
            email: email,
            password: password,
            securityQuestion: question,
            securityAnswer: answer
        )
        guard case .started = first else {
            return XCTFail("Expected the first start to succeed")
        }

        let second = await opening.start(
            email: email,
            password: password,
            securityQuestion: question,
            securityAnswer: answer
        )
        guard case .refused(let notice) = second else {
            return XCTFail("Expected a refusal")
        }
        XCTAssertEqual(notice.message, SessionOpening.emailTakenMessage)
        XCTAssertEqual(try context.count(for: User.fetchRequest()), 1)
    }

    func testStartKeepsTheSessionWhenTheClaimMarkFails() async throws {
        let email = freshEmail("claim")
        var marks = 0
        let (context, opening) = try makeOpening {
            marks += 1
            return false
        }
        let outcome = await opening.start(
            email: email,
            password: password,
            securityQuestion: question,
            securityAnswer: answer
        )
        guard case .claimPending(let notice) = outcome else {
            return XCTFail("Expected the Claim miss")
        }
        XCTAssertEqual(notice.message, SessionOpening.claimPendingMessage)
        XCTAssertEqual(marks, 1)
        XCTAssertEqual(try context.count(for: User.fetchRequest()), 1)
        let user = try XCTUnwrap(fetchUser(email, in: context))
        XCTAssertEqual(UserManager.shared.sessionUserId, user.id)
        XCTAssertNotNil(UserManager.shared.secrets.load(userId: user.id!)?.passwordHash)
    }

    func testResetRefusesAWeakPasswordWithoutCountingAnAttempt() async throws {
        let email = freshEmail("weak-reset")
        let (_, opening) = try makeOpening()
        let started = await opening.start(
            email: email,
            password: password,
            securityQuestion: question,
            securityAnswer: answer
        )
        guard case .started = started else {
            return XCTFail("Expected a Session")
        }

        let result = await opening.reset(email: email, newPassword: "password123", securityAnswer: answer)
        XCTAssertFalse(result.success)
        XCTAssertEqual(result.title, "Weak Password")
        XCTAssertTrue(result.message.contains("uppercase"))
        XCTAssertEqual(AccountLockoutManager.shared.getFailedAttempts(email: email), 0)
    }

    func testResetDoesNotTreatWaitingAsAWrongAnswer() async throws {
        let email = freshEmail("waiting")
        let (context, opening) = try makeOpening()
        let user = User(context: context)
        user.id = UUID()
        user.email = email
        user.isActive = true
        try context.save()

        let result = await opening.reset(email: email, newPassword: password, securityAnswer: "not-the-answer")
        XCTAssertFalse(result.success)
        XCTAssertEqual(result.message, SessionSecretMessage.waiting)
        XCTAssertEqual(AccountLockoutManager.shared.getFailedAttempts(email: email), 0)
        XCTAssertNil(UserManager.shared.secrets.load(userId: user.id!))
    }

    func testLockedResetDoesNotCheckOrUpgradeTheAnswer() async throws {
        let email = freshEmail("locked")
        defer { AccountLockoutManager.shared.manuallyUnlock(email: email) }
        let (context, opening) = try makeOpening()
        let user = User(context: context)
        user.id = UUID()
        user.email = email
        user.securityQuestion = question
        user.securityAnswerHash = legacyHash("Fluffy")
        user.isActive = true
        try context.save()
        for _ in 1...5 {
            let miss = await opening.reset(email: email, newPassword: password, securityAnswer: "nope")
            XCTAssertFalse(miss.success)
        }

        let result = await opening.reset(email: email, newPassword: password, securityAnswer: "Fluffy")
        XCTAssertFalse(result.success)
        XCTAssertEqual(result.title, "Account Locked")
        XCTAssertTrue(result.message.contains("Too many failed attempts"))
        let secret = UserManager.shared.secrets.load(userId: user.id!)
        XCTAssertNil(user.securityAnswerHash)
        XCTAssertNil(user.securityAnswerSalt)
        XCTAssertEqual(secret?.securityAnswerHash, legacyHash("Fluffy"))
        XCTAssertNil(secret?.securityAnswerIterations)
    }

    func testLoginStartsTheSessionAndClearsTheCount() async throws {
        let email = freshEmail("login")
        let (context, opening) = try makeOpening()
        try await startSession(email: email, opening: opening)
        UserManager.shared.clearSession()

        let miss = await opening.login(email: email, password: "WrongPass1")
        guard case .refused(let refused) = miss else {
            return XCTFail("Expected a refusal")
        }
        XCTAssertEqual(refused.title, "Login Failed")
        XCTAssertTrue(refused.message.contains("4 attempts remaining"))
        XCTAssertNil(UserManager.shared.sessionUserId)

        let started = await opening.login(email: email, password: password)
        guard case .started = started else {
            return XCTFail("Expected the Session to start")
        }
        let user = try XCTUnwrap(fetchUser(email, in: context))
        XCTAssertEqual(UserManager.shared.sessionUserId, user.id)
        XCTAssertEqual(AccountLockoutManager.shared.getFailedAttempts(email: email), 0)
    }

    func testUnknownEmailCountsAsALoginMiss() async throws {
        let email = freshEmail("missing")
        let (_, opening) = try makeOpening()
        let outcome = await opening.login(email: email, password: password)
        guard case .refused(let notice) = outcome else {
            return XCTFail("Expected a refusal")
        }
        XCTAssertEqual(notice.title, "Login Failed")
        XCTAssertTrue(notice.message.contains("4 attempts remaining"))
        XCTAssertEqual(AccountLockoutManager.shared.getFailedAttempts(email: email), 1)
        XCTAssertNil(UserManager.shared.sessionUserId)
    }

    func testFifthLoginMissLocksAndALaterPasswordDoesNotClearIt() async throws {
        let email = freshEmail("lock-login")
        defer { AccountLockoutManager.shared.manuallyUnlock(email: email) }
        let (context, opening) = try makeOpening()
        let user = User(context: context)
        user.id = UUID()
        user.email = email
        user.isActive = true
        let legacy = SHA256.hash(data: Data(password.utf8)).compactMap { String(format: "%02x", $0) }.joined()
        user.passwordHash = legacy
        try context.save()

        for index in 1...4 {
            let miss = await opening.login(email: email, password: "WrongPass1")
            guard case .refused = miss else {
                return XCTFail("Miss \(index) should be a refusal")
            }
        }
        let locking = await opening.login(email: email, password: "WrongPass1")
        guard case .locked(let locked) = locking else {
            return XCTFail("The fifth miss should lock")
        }
        XCTAssertEqual(locked.title, "Account Locked")
        XCTAssertTrue(locked.message.hasPrefix("Too many failed attempts. Try again in"))

        let ignored = await opening.login(email: email, password: password)
        guard case .locked = ignored else {
            return XCTFail("A locked email stays locked")
        }
        XCTAssertNil(UserManager.shared.sessionUserId)
        XCTAssertEqual(AccountLockoutManager.shared.getFailedAttempts(email: email), 5)
        let secret = UserManager.shared.secrets.load(userId: user.id!)
        XCTAssertEqual(secret?.passwordHash, legacy)
        XCTAssertNil(secret?.passwordIterations)
    }

    func testLoginWaitingDoesNotCount() async throws {
        let email = freshEmail("login-wait")
        let (context, opening) = try makeOpening()
        let user = User(context: context)
        user.id = UUID()
        user.email = email
        user.isActive = true
        try context.save()

        let outcome = await opening.login(email: email, password: password)
        guard case .waiting(let notice) = outcome else {
            return XCTFail("Expected waiting")
        }
        XCTAssertEqual(notice, SessionOpening.waitingNotice)
        XCTAssertEqual(AccountLockoutManager.shared.getFailedAttempts(email: email), 0)
        XCTAssertNil(UserManager.shared.sessionUserId)
    }

    func testFourLoginMissesAndOneWrongAnswerLock() async throws {
        let email = freshEmail("mix-login")
        defer { AccountLockoutManager.shared.manuallyUnlock(email: email) }
        let (_, opening) = try makeOpening()
        try await startSession(email: email, opening: opening)
        UserManager.shared.clearSession()

        for index in 1...4 {
            let miss = await opening.login(email: email, password: "WrongPass1")
            guard case .refused = miss else {
                return XCTFail("Login miss \(index) should be a refusal")
            }
        }
        let locking = await opening.reset(email: email, newPassword: password, securityAnswer: "not-the-answer")
        XCTAssertFalse(locking.success)
        XCTAssertEqual(locking.title, "Account Locked")
        XCTAssertTrue(locking.message.hasPrefix("Too many failed attempts. Try again in"))
        XCTAssertEqual(AccountLockoutManager.shared.getFailedAttempts(email: email), 5)
    }

    func testFourWrongAnswersAndOneLoginMissLock() async throws {
        let email = freshEmail("mix-answer")
        defer { AccountLockoutManager.shared.manuallyUnlock(email: email) }
        let (_, opening) = try makeOpening()
        try await startSession(email: email, opening: opening)
        UserManager.shared.clearSession()

        for index in 1...4 {
            let miss = await opening.reset(email: email, newPassword: password, securityAnswer: "not-the-answer")
            XCTAssertFalse(miss.success, "Answer miss \(index)")
            XCTAssertEqual(miss.title, "Error")
        }
        let locking = await opening.login(email: email, password: "WrongPass1")
        guard case .locked(let locked) = locking else {
            return XCTFail("The fifth miss should lock")
        }
        XCTAssertEqual(locked.title, "Account Locked")
        XCTAssertTrue(locked.message.hasPrefix("Too many failed attempts. Try again in"))
        XCTAssertEqual(AccountLockoutManager.shared.getFailedAttempts(email: email), 5)
    }

    func testUnknownEmailResetLeavesTheCountUnchanged() async throws {
        let email = freshEmail("unknown-reset")
        let (_, opening) = try makeOpening()
        let result = await opening.reset(email: email, newPassword: password, securityAnswer: "not-the-answer")
        XCTAssertFalse(result.success)
        XCTAssertEqual(result.title, "Error")
        XCTAssertTrue(result.message.contains("Security answer is incorrect."))
        XCTAssertTrue(result.message.contains("5 attempts remaining"))
        XCTAssertEqual(AccountLockoutManager.shared.getFailedAttempts(email: email), 0)
    }

    func testResetWithNoSecurityAnswerCountsAsAMiss() async throws {
        let email = freshEmail("no-answer")
        defer { AccountLockoutManager.shared.manuallyUnlock(email: email) }
        let (context, opening) = try makeOpening()
        let user = User(context: context)
        user.id = UUID()
        user.email = email
        user.isActive = true
        try context.save()
        var secret = SessionSecret()
        secret.passwordHash = "stored"
        XCTAssertTrue(UserManager.shared.secrets.save(secret, userId: try XCTUnwrap(user.id)))

        let result = await opening.reset(email: email, newPassword: password, securityAnswer: "not-the-answer")
        XCTAssertFalse(result.success)
        XCTAssertEqual(result.title, "Error")
        XCTAssertTrue(result.message.contains("Security answer is incorrect."))
        XCTAssertTrue(result.message.contains("4 attempts remaining"))
        XCTAssertEqual(AccountLockoutManager.shared.getFailedAttempts(email: email), 1)
    }

    func testResetAcceptsASecurityAnswerInAnyCase() async throws {
        let email = freshEmail("case")
        let (_, opening) = try makeOpening()
        try await startSession(email: email, opening: opening)
        let result = await opening.reset(email: email, newPassword: "NewPassword1", securityAnswer: "FLUFFY12")
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.title, "Success")
        XCTAssertEqual(result.message, "Password has been reset successfully!")
    }

    func testResetTrimsTheSecurityAnswer() async throws {
        let email = freshEmail("trim")
        let (_, opening) = try makeOpening()
        try await startSession(email: email, opening: opening)
        let result = await opening.reset(email: email, newPassword: "NewPassword1", securityAnswer: "  Fluffy12  ")
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.title, "Success")
    }

    func testResetUpgradesALegacySecurityAnswer() async throws {
        let email = freshEmail("legacy-answer")
        let (context, opening) = try makeOpening()
        try await startSession(email: email, opening: opening)
        let user = try XCTUnwrap(fetchUser(email, in: context))
        let userId = try XCTUnwrap(user.id)
        var secret = try XCTUnwrap(UserManager.shared.secrets.load(userId: userId))
        secret.securityAnswerHash = legacyHash(answer)
        secret.securityAnswerSalt = nil
        secret.securityAnswerIterations = nil
        XCTAssertTrue(UserManager.shared.secrets.save(secret, userId: userId))

        let result = await opening.reset(email: email, newPassword: "NewPassword1", securityAnswer: "  FLUFFY12 ")
        XCTAssertTrue(result.success)
        let upgraded = UserManager.shared.secrets.load(userId: userId)
        XCTAssertNotNil(upgraded?.securityAnswerSalt)
        XCTAssertEqual(upgraded?.securityAnswerIterations, SessionSecretRules.iterations)
        XCTAssertNotEqual(upgraded?.securityAnswerHash, legacyHash(answer))
        XCTAssertEqual(AccountLockoutManager.shared.getFailedAttempts(email: email), 0)
    }

    func testResetWrongAnswerReportsAttemptsLeft() async throws {
        let email = freshEmail("reset-count")
        defer { AccountLockoutManager.shared.manuallyUnlock(email: email) }
        let (_, opening) = try makeOpening()
        try await startSession(email: email, opening: opening)

        let result = await opening.reset(email: email, newPassword: password, securityAnswer: "not-the-answer")
        XCTAssertFalse(result.success)
        XCTAssertEqual(result.title, "Error")
        XCTAssertTrue(result.message.contains("Security answer is incorrect."))
        XCTAssertTrue(result.message.contains("4 attempts remaining"))
        XCTAssertEqual(AccountLockoutManager.shared.getFailedAttempts(email: email), 1)
    }

    func testConfirmDeletionIgnoresTheLockAndAWrongPassword() async throws {
        let email = freshEmail("delete")
        defer { AccountLockoutManager.shared.manuallyUnlock(email: email) }
        let (context, opening) = try makeOpening()
        try await startSession(email: email, opening: opening)
        for _ in 1...2 {
            _ = await opening.login(email: email, password: "WrongPass1")
        }
        XCTAssertEqual(AccountLockoutManager.shared.getFailedAttempts(email: email), 2)

        let wrong = await opening.confirmDeletion(password: "WrongPass1")
        guard case .refused(let refused) = wrong else {
            return XCTFail("Expected a refusal")
        }
        XCTAssertEqual(refused, SessionOpening.deletionRefused)
        XCTAssertEqual(AccountLockoutManager.shared.getFailedAttempts(email: email), 2)

        for _ in 1...3 {
            _ = await opening.login(email: email, password: "WrongPass1")
        }
        XCTAssertTrue(AccountLockoutManager.shared.isAccountLocked(email: email))
        let user = try XCTUnwrap(fetchUser(email, in: context))
        UserManager.shared.startSession(userId: try XCTUnwrap(user.id))

        let matched = await opening.confirmDeletion(password: password)
        guard case .matched = matched else {
            return XCTFail("A locked email can still confirm Delete Account")
        }
        XCTAssertTrue(AccountLockoutManager.shared.isAccountLocked(email: email))
        XCTAssertEqual(AccountLockoutManager.shared.getFailedAttempts(email: email), 5)
    }

    func testConfirmDeletionWaitingDoesNotCount() async throws {
        let email = freshEmail("delete-wait")
        let (context, opening) = try makeOpening()
        let user = User(context: context)
        user.id = UUID()
        user.email = email
        user.isActive = true
        try context.save()
        UserManager.shared.startSession(userId: try XCTUnwrap(user.id))

        let outcome = await opening.confirmDeletion(password: password)
        guard case .waiting(let notice) = outcome else {
            return XCTFail("Expected waiting")
        }
        XCTAssertEqual(notice, SessionOpening.waitingNotice)
        XCTAssertEqual(AccountLockoutManager.shared.getFailedAttempts(email: email), 0)
    }

    private func startSession(email: String, opening: SessionOpening) async throws {
        let started = await opening.start(
            email: email,
            password: password,
            securityQuestion: question,
            securityAnswer: answer
        )
        guard case .started = started else {
            XCTFail("Expected a Session")
            return
        }
    }

    private func assertPasswordRefusal(_ password: String, fragment: String) async throws {
        let (context, opening) = try makeOpening()
        let outcome = await opening.start(
            email: freshEmail("password"),
            password: password,
            securityQuestion: question,
            securityAnswer: answer
        )
        guard case .refused(let notice) = outcome else {
            return XCTFail("Expected a refusal")
        }
        XCTAssertEqual(notice.title, "Weak Password")
        XCTAssertTrue(notice.message.contains(fragment))
        XCTAssertEqual(try context.count(for: User.fetchRequest()), 0)
    }

    private func makeOpening(mark: @escaping () async -> Bool = { true }) throws -> (NSManagedObjectContext, SessionOpening) {
        let context = try makeContext()
        let opening = SessionOpening(
            context: { context },
            storeReady: { true },
            markClaim: mark
        )
        return (context, opening)
    }

    private func makeContext() throws -> NSManagedObjectContext {
        guard let model = NSManagedObjectModel.mergedModel(from: [Bundle(for: CoreDataManager.self)]) else {
            throw NSError(domain: "SessionOpeningTests", code: 1)
        }
        let container = NSPersistentContainer(name: "Systems_Inspector", managedObjectModel: model)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        description.shouldAddStoreAsynchronously = false
        container.persistentStoreDescriptions = [description]
        var loadError: Error?
        container.loadPersistentStores { _, error in loadError = error }
        if let loadError { throw loadError }
        self.container = container
        return container.viewContext
    }

    private func fetchUser(_ email: String, in context: NSManagedObjectContext) throws -> User? {
        let request: NSFetchRequest<User> = User.fetchRequest()
        request.predicate = NSPredicate(format: "email == %@", email)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    private func freshEmail(_ label: String) -> String {
        "\(label)-\(UUID().uuidString)@example.com".lowercased()
    }

    private func legacyHash(_ answer: String) -> String {
        let normalized = answer.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let data = Data(normalized.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
