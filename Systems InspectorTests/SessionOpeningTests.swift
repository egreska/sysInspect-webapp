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
            XCTAssertFalse(PasswordRecoveryManager.shared.verifySecurityAnswer(
                for: email,
                answer: "nope",
                in: context
            ))
        }

        let result = await opening.reset(email: email, newPassword: password, securityAnswer: "Fluffy")
        XCTAssertFalse(result.success)
        XCTAssertTrue(result.message.contains("Too many failed attempts"))
        let secret = UserManager.shared.secrets.load(userId: user.id!)
        XCTAssertNil(user.securityAnswerHash)
        XCTAssertNil(user.securityAnswerSalt)
        XCTAssertEqual(secret?.securityAnswerHash, legacyHash("Fluffy"))
        XCTAssertNil(secret?.securityAnswerIterations)
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
