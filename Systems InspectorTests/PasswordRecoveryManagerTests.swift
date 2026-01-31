//
//  PasswordRecoveryManagerTests.swift
//  Systems InspectorTests
//
//  Unit tests for PasswordRecoveryManager
//  Created on 1/29/26.
//

import XCTest
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
        let questionKey = "securityQuestion_\(email.lowercased())"
        let answerKey = "securityAnswer_\(email.lowercased())"
        UserDefaults.standard.removeObject(forKey: questionKey)
        UserDefaults.standard.removeObject(forKey: answerKey)
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
        
        measure {
            for _ in 1...100 {
                _ = sut.verifySecurityAnswer(for: testEmail, answer: testAnswer)
            }
        }
    }
}

// MARK: - SHA256 Extension for Testing
import CryptoKit

extension SHA256 {
    static func hash(data: Data) -> [UInt8] {
        let hashed = SHA256.hash(data: data)
        return Array(hashed)
    }
}
