//
//  LoginFlowUITests.swift
//  Systems InspectorUITests
//
//  UI tests for login and authentication flows
//  Created on 1/29/26.
//

import XCTest

final class LoginFlowUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        
        app = XCUIApplication()
        app.launchArguments = ["UI-Testing"]
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Login Screen Tests
    
    func testLoginScreenElementsExist() {
        // Given: App launched
        
        // Then: All login elements should be visible
        XCTAssertTrue(app.textFields["Email"].exists)
        XCTAssertTrue(app.secureTextFields["Password"].exists)
        XCTAssertTrue(app.buttons["Log In"].exists)
        XCTAssertTrue(app.buttons["Log In with Face ID"].exists || app.buttons["Log In with Touch ID"].exists)
        XCTAssertTrue(app.buttons["Forgot Password?"].exists)
        XCTAssertTrue(app.buttons["Create New Account"].exists)
    }
    
    func testLoginWithEmptyFields() {
        // Given: Login screen
        
        // When: Tapping login without entering credentials
        app.buttons["Log In"].tap()
        
        // Then: Should show error alert
        XCTAssertTrue(app.alerts["Error"].exists)
        XCTAssertTrue(app.alerts["Error"].staticTexts["Please enter both email and password."].exists)
        
        app.alerts["Error"].buttons["OK"].tap()
    }
    
    func testLoginWithInvalidEmail() {
        // Given: Login screen
        let emailField = app.textFields["Email"]
        let passwordField = app.secureTextFields["Password"]
        
        // When: Entering invalid email
        emailField.tap()
        emailField.typeText("invalid-email")
        
        passwordField.tap()
        passwordField.typeText("Password123")
        
        app.buttons["Log In"].tap()
        
        // Then: Should show login failed (assuming no user exists)
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
    }
    
    func testNavigateToCreateAccount() {
        // Given: Login screen
        
        // When: Tapping create account
        app.buttons["Create New Account"].tap()
        
        // Then: Should navigate to account creation
        XCTAssertTrue(app.navigationBars["Create Account"].exists)
        XCTAssertTrue(app.textFields["Email"].exists)
        XCTAssertTrue(app.secureTextFields["Password"].exists)
        XCTAssertTrue(app.buttons["Create Account"].exists)
    }
    
    func testNavigateToForgotPassword() {
        // Given: Login screen
        
        // When: Tapping forgot password
        app.buttons["Forgot Password?"].tap()
        
        // Then: Should show forgot password screen
        XCTAssertTrue(app.navigationBars["Reset Password"].exists || app.staticTexts["Reset Password"].exists)
    }
    
    // MARK: - Account Creation Tests
    
    func testAccountCreationFieldsExist() {
        // Given: Navigate to account creation
        app.buttons["Create New Account"].tap()
        
        // Then: All fields should exist
        XCTAssertTrue(app.textFields["Email"].exists)
        XCTAssertTrue(app.secureTextFields["Password"].exists)
        XCTAssertTrue(app.secureTextFields["Confirm Password"].exists)
        XCTAssertTrue(app.buttons["Select a Security Question"].exists)
        XCTAssertTrue(app.buttons["Create Account"].exists)
    }
    
    func testAccountCreationWithMismatchedPasswords() {
        // Given: Account creation screen
        app.buttons["Create New Account"].tap()
        
        let emailField = app.textFields["Email"]
        let passwordField = app.secureTextFields["Password"].firstMatch
        let confirmField = app.secureTextFields["Confirm Password"]
        
        // When: Entering mismatched passwords
        emailField.tap()
        emailField.typeText("test@example.com")
        
        passwordField.tap()
        passwordField.typeText("Password123")
        
        confirmField.tap()
        confirmField.typeText("DifferentPass123")
        
        // Select security question
        app.buttons["Select a Security Question"].tap()
        app.buttons["What was the name of your first pet?"].tap()
        
        let answerField = app.textFields.matching(identifier: "Your Answer").firstMatch
        answerField.tap()
        answerField.typeText("Fluffy")
        
        app.buttons["Create Account"].tap()
        
        // Then: Should show error
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        XCTAssertTrue(alert.staticTexts["Passwords do not match."].exists)
    }
    
    func testAccountCreationRequiresSecurityQuestion() {
        // Given: Account creation screen
        app.buttons["Create New Account"].tap()
        
        let emailField = app.textFields["Email"]
        let passwordField = app.secureTextFields["Password"].firstMatch
        let confirmField = app.secureTextFields["Confirm Password"]
        
        // When: Filling without security question
        emailField.tap()
        emailField.typeText("test@example.com")
        
        passwordField.tap()
        passwordField.typeText("Password123")
        
        confirmField.tap()
        confirmField.typeText("Password123")
        
        app.buttons["Create Account"].tap()
        
        // Then: Should show error
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        XCTAssertTrue(alert.staticTexts.containing(NSPredicate(format: "label CONTAINS 'security question'")).firstMatch.exists)
    }
    
    // MARK: - Account Lockout Tests
    
    func testAccountLockoutAfterFailedAttempts() {
        // Given: Login screen
        let emailField = app.textFields["Email"]
        let passwordField = app.secureTextFields["Password"]
        let loginButton = app.buttons["Log In"]
        
        // When: Attempting login with wrong password 5 times
        for attempt in 1...5 {
            emailField.tap()
            emailField.clearText()
            emailField.typeText("test@example.com")
            
            passwordField.tap()
            passwordField.clearText()
            passwordField.typeText("WrongPassword\(attempt)")
            
            loginButton.tap()
            
            // Wait for alert
            let alert = app.alerts.firstMatch
            XCTAssertTrue(alert.waitForExistence(timeout: 5))
            
            if attempt < 5 {
                // Should show remaining attempts
                XCTAssertTrue(alert.staticTexts.containing(NSPredicate(format: "label CONTAINS 'attempt'")).firstMatch.exists)
            } else {
                // Should show account locked
                XCTAssertTrue(alert.staticTexts.containing(NSPredicate(format: "label CONTAINS 'locked'")).firstMatch.exists)
            }
            
            alert.buttons["OK"].tap()
        }
    }
    
    // MARK: - Helper Methods
    
    private func clearAndEnterText(element: XCUIElement, text: String) {
        element.tap()
        
        if let value = element.value as? String, !value.isEmpty {
            element.clearText()
        }
        
        element.typeText(text)
    }
}

// MARK: - XCUIElement Extensions

extension XCUIElement {
    func clearText() {
        guard let stringValue = self.value as? String else {
            return
        }
        
        // Tap to focus
        self.tap()
        
        // Select all and delete
        if stringValue.count > 0 {
            let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: stringValue.count)
            self.typeText(deleteString)
        }
    }
}
