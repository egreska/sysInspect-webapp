//
//  PasswordRecoveryManagerTests.swift
//  Systems InspectorTests
//
//  Unit tests for PasswordRecoveryManager
//  Created on 1/29/26.
//

import XCTest
import CoreData
import CryptoKit
@testable import Systems_Inspector

final class PasswordRecoveryManagerTests: XCTestCase {
    
    var sut: PasswordRecoveryManager!
    let testEmail = "test@example.com"
    let testQuestion = "What was the name of your first pet?"
    let testAnswer = "Fluffy"
    
    override func setUp() {
        super.setUp()
        UserManager.shared.use(secrets: MemorySessionSecretStore())
        sut = PasswordRecoveryManager.shared
        
        // Clear any existing security questions
        clearSecurityQuestion(for: testEmail)
    }
    
    override func tearDown() {
        clearSecurityQuestion(for: testEmail)
        sut = nil
        super.tearDown()
    }
    
    private func clearSecurityQuestion(for email: String) {
        sut.clearSecurityQuestion(for: email)
        AccountLockoutManager.shared.manuallyUnlock(email: email)
    }

    private func legacyHash(_ answer: String) -> String {
        let normalized = answer.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let data = Data(normalized.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    private func storeLegacyAnswer(_ answer: String) {
        let email = testEmail.lowercased()
        UserDefaults.standard.set(testQuestion, forKey: "securityQuestion_\(email)")
        UserDefaults.standard.set(legacyHash(answer), forKey: "securityAnswer_\(email)")
    }

    // MARK: - Security Question Tests
    
    func testAvailableQuestionsNotEmpty() {
        // Given: Available security questions
        
        // Then: Should have at least 5 questions
        XCTAssertGreaterThanOrEqual(PasswordRecoveryManager.availableQuestions.count, 5)
    }
    
    func testHasSecurityQuestionInitiallyFalse() {
        // Given: Email without security question
        
        // When: Checking if has security question
        let hasQuestion = sut.hasSecurityQuestion(for: testEmail)
        
        // Then: Should be false
        XCTAssertFalse(hasQuestion, "Should not have security question initially")
    }
    
    func testGetSecurityQuestionReturnsNilInitially() {
        // Given: Email without security question
        
        // When: Getting security question
        let question = sut.getSecurityQuestion(for: testEmail)
        
        // Then: Should be nil
        XCTAssertNil(question, "Should not have security question initially")
    }
    
    func testNewSecurityAnswerMustBeEightCharactersAfterTrim() {
        let short = sut.validateSecurityAnswer("  fluffy  ")
        XCTAssertFalse(short.isValid)
        XCTAssertTrue(short.message.contains("8 characters"))
        let long = sut.validateSecurityAnswer("  Fluffy12  ")
        XCTAssertTrue(long.isValid)
    }

    func testPhoneAnswerCopiesOntoTheSessionOnce() throws {
        guard let model = NSManagedObjectModel.mergedModel(from: [Bundle(for: CoreDataManager.self)]) else {
            XCTFail("Missing Core Data model")
            return
        }
        let container = NSPersistentContainer(name: "Systems_Inspector", managedObjectModel: model)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        description.shouldAddStoreAsynchronously = false
        container.persistentStoreDescriptions = [description]
        var loadError: Error?
        container.loadPersistentStores { _, error in loadError = error }
        XCTAssertNil(loadError)
        let context = container.viewContext
        let user = User(context: context)
        user.id = UUID()
        user.email = testEmail.lowercased()
        user.isActive = true
        try context.save()
        storeLegacyAnswer(testAnswer)

        sut.adoptPhoneAnswer(for: testEmail, in: context)

        let email = testEmail.lowercased()
        let secret = UserManager.shared.secrets.load(userId: user.id!)
        XCTAssertNil(user.securityQuestion)
        XCTAssertNil(user.securityAnswerHash)
        XCTAssertEqual(secret?.securityQuestion, testQuestion)
        XCTAssertEqual(secret?.securityAnswerHash, legacyHash(testAnswer))
        XCTAssertNil(secret?.securityAnswerIterations)
        XCTAssertNil(UserDefaults.standard.string(forKey: "securityAnswer_\(email)"))
        let kept = secret?.securityAnswerHash
        UserDefaults.standard.set(legacyHash("other"), forKey: "securityAnswer_\(email)")
        sut.adoptPhoneAnswer(for: testEmail, in: context)
        XCTAssertEqual(UserManager.shared.secrets.load(userId: user.id!)?.securityAnswerHash, kept)
        XCTAssertNil(UserDefaults.standard.string(forKey: "securityAnswer_\(email)"))
    }

}
