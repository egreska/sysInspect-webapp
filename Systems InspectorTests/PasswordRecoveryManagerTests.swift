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
    
    // MARK: - Set Security Question Tests
    
    func testSetSecurityQuestionSuccess() {
        // Given: A valid question and answer
        
        // When: Setting security question
        // Note: This requires Core Data user to exist, so we'll test the storage mechanism
        let questionKey = "securityQuestion_\(testEmail.lowercased())"
        let answerKey = "securityAnswer_\(testEmail.lowercased())"
        
        UserDefaults.standard.set(testQuestion, forKey: questionKey)
        UserDefaults.standard.set("someHash", forKey: answerKey)
        
        // Then: Should be retrievable
        XCTAssertTrue(sut.hasSecurityQuestion(for: testEmail))
        XCTAssertEqual(sut.getSecurityQuestion(for: testEmail), testQuestion)
    }
    
    // MARK: - Password Validation Tests
    
    func testValidatePasswordTooShort() {
        // Given: A short password
        let password = "Pass1"
        
        // When: Validating
        let result = sut.validatePasswordStrength(password)
        
        // Then: Should fail
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.message.contains("8 characters"))
    }
    
    func testValidatePasswordNoUppercase() {
        // Given: Password without uppercase
        let password = "password123"
        
        // When: Validating
        let result = sut.validatePasswordStrength(password)
        
        // Then: Should fail
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.message.contains("uppercase"))
    }
    
    func testValidatePasswordNoLowercase() {
        // Given: Password without lowercase
        let password = "PASSWORD123"
        
        // When: Validating
        let result = sut.validatePasswordStrength(password)
        
        // Then: Should fail
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.message.contains("lowercase"))
    }
    
    func testValidatePasswordNoNumber() {
        // Given: Password without number
        let password = "PasswordOnly"
        
        // When: Validating
        let result = sut.validatePasswordStrength(password)
        
        // Then: Should fail
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.message.contains("number"))
    }
    
    func testValidatePasswordValid() {
        // Given: A strong password
        let password = "Password123"
        
        // When: Validating
        let result = sut.validatePasswordStrength(password)
        
        // Then: Should pass
        XCTAssertTrue(result.isValid)
        XCTAssertTrue(result.message.contains("meets requirements"))
    }
    
    // MARK: - Security Answer Tests
    
    func testNewSecurityAnswerMustBeEightCharactersAfterTrim() throws {
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

        let short = sut.validateSecurityAnswer("  fluffy  ")
        XCTAssertFalse(short.isValid)
        XCTAssertFalse(sut.setSecurityQuestion(
            for: testEmail,
            question: testQuestion,
            answer: "  fluffy  ",
            in: context
        ))
        XCTAssertNil(user.securityAnswerHash)

        let long = sut.validateSecurityAnswer("  Fluffy12  ")
        XCTAssertTrue(long.isValid)
        XCTAssertTrue(sut.setSecurityQuestion(
            for: testEmail,
            question: testQuestion,
            answer: "  Fluffy12  ",
            in: context
        ))
        XCTAssertTrue(sut.verifySecurityAnswer(for: testEmail, answer: "fluffy12", in: context))
    }

    func testVerifySecurityAnswerCaseInsensitive() {
        // Given: Security question set with answer "Fluffy"
        let questionKey = "securityQuestion_\(testEmail.lowercased())"
        let answerKey = "securityAnswer_\(testEmail.lowercased())"
        
        // Create hash of lowercase answer
        let normalized = testAnswer.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let data = Data(normalized.utf8)
        let hash = SHA256.hash(data: data)
        let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()
        
        UserDefaults.standard.set(testQuestion, forKey: questionKey)
        UserDefaults.standard.set(hashString, forKey: answerKey)
        
        // When: Verifying with different case
        let isValid1 = sut.verifySecurityAnswer(for: testEmail, answer: "fluffy")
        let isValid2 = sut.verifySecurityAnswer(for: testEmail, answer: "FLUFFY")
        let isValid3 = sut.verifySecurityAnswer(for: testEmail, answer: "Fluffy")
        
        // Then: All should pass (case-insensitive)
        XCTAssertTrue(isValid1, "Should accept lowercase")
        XCTAssertTrue(isValid2, "Should accept uppercase")
        XCTAssertTrue(isValid3, "Should accept mixed case")
    }
    
    func testVerifySecurityAnswerTrimsWhitespace() {
        // Given: Security question with answer
        let questionKey = "securityQuestion_\(testEmail.lowercased())"
        let answerKey = "securityAnswer_\(testEmail.lowercased())"
        
        let normalized = testAnswer.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let data = Data(normalized.utf8)
        let hash = SHA256.hash(data: data)
        let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()
        
        UserDefaults.standard.set(testQuestion, forKey: questionKey)
        UserDefaults.standard.set(hashString, forKey: answerKey)
        
        // When: Verifying with whitespace
        let isValid = sut.verifySecurityAnswer(for: testEmail, answer: "  fluffy  ")
        
        // Then: Should pass (whitespace trimmed)
        XCTAssertTrue(isValid, "Should trim whitespace from answer")
    }
    
    func testVerifySecurityAnswerWrongAnswer() {
        // Given: Security question set
        let questionKey = "securityQuestion_\(testEmail.lowercased())"
        let answerKey = "securityAnswer_\(testEmail.lowercased())"
        
        let normalized = testAnswer.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let data = Data(normalized.utf8)
        let hash = SHA256.hash(data: data)
        let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()
        
        UserDefaults.standard.set(testQuestion, forKey: questionKey)
        UserDefaults.standard.set(hashString, forKey: answerKey)
        
        // When: Verifying wrong answer
        let isValid = sut.verifySecurityAnswer(for: testEmail, answer: "WrongAnswer")
        
        // Then: Should fail
        XCTAssertFalse(isValid, "Should reject wrong answer")
    }

    func testLegacyAnswerIsSavedWithSaltAfterOneMatch() {
        storeLegacyAnswer(testAnswer)

        XCTAssertTrue(sut.verifySecurityAnswer(for: testEmail, answer: "fluffy"))

        let email = testEmail.lowercased()
        let salt = UserDefaults.standard.data(forKey: "securityAnswerSalt_\(email)")
        let stored = UserDefaults.standard.string(forKey: "securityAnswer_\(email)")
        XCTAssertNotNil(salt)
        XCTAssertNotEqual(stored, legacyHash(testAnswer))
        XCTAssertTrue(UserManager.shared.verifyPasswordSecure("fluffy", hash: stored!, salt: salt!))
        XCTAssertTrue(sut.verifySecurityAnswer(for: testEmail, answer: "  FLUFFY "))
        XCTAssertEqual(AccountLockoutManager.shared.getFailedAttempts(email: testEmail), 0)
    }

    func testLockedResetDoesNotCheckOrUpgradeTheAnswer() async {
        storeLegacyAnswer(testAnswer)
        for _ in 1...5 {
            XCTAssertFalse(sut.verifySecurityAnswer(for: testEmail, answer: "nope"))
        }

        let result = await sut.resetPassword(
            for: testEmail,
            newPassword: "Password123",
            securityAnswer: testAnswer
        )

        XCTAssertFalse(result.success)
        XCTAssertTrue(result.message.contains("Too many failed attempts"))
        let email = testEmail.lowercased()
        XCTAssertNil(UserDefaults.standard.data(forKey: "securityAnswerSalt_\(email)"))
        XCTAssertEqual(
            UserDefaults.standard.string(forKey: "securityAnswer_\(email)"),
            legacyHash(testAnswer)
        )
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
        XCTAssertEqual(user.securityQuestion, testQuestion)
        XCTAssertEqual(user.securityAnswerHash, legacyHash(testAnswer))
        XCTAssertNil(user.securityAnswerSalt)
        XCTAssertNil(UserDefaults.standard.string(forKey: "securityAnswer_\(email)"))
        XCTAssertTrue(sut.verifySecurityAnswer(for: testEmail, answer: "fluffy", in: context))
        XCTAssertNotNil(user.securityAnswerSalt)
        let kept = user.securityAnswerHash
        UserDefaults.standard.set(legacyHash("other"), forKey: "securityAnswer_\(email)")
        sut.adoptPhoneAnswer(for: testEmail, in: context)
        XCTAssertEqual(user.securityAnswerHash, kept)
        XCTAssertNil(UserDefaults.standard.string(forKey: "securityAnswer_\(email)"))
    }

    // MARK: - Performance Tests
    
    func testPerformancePasswordValidation() {
        let passwords = ["Password123", "weak", "NoNumbers", "nocaps123", "NOLOWER123"]
        
        measure {
            for password in passwords {
                _ = sut.validatePasswordStrength(password)
            }
        }
    }
    
    func testPerformanceSecurityAnswerVerification() {
        // Setup
        let questionKey = "securityQuestion_\(testEmail.lowercased())"
        let answerKey = "securityAnswer_\(testEmail.lowercased())"
        
        let normalized = testAnswer.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let data = Data(normalized.utf8)
        let hash = SHA256.hash(data: data)
        let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()
        
        UserDefaults.standard.set(testQuestion, forKey: questionKey)
        UserDefaults.standard.set(hashString, forKey: answerKey)
        
        _ = sut.verifySecurityAnswer(for: testEmail, answer: testAnswer)
        measure {
            _ = sut.verifySecurityAnswer(for: testEmail, answer: testAnswer)
        }
    }
}
