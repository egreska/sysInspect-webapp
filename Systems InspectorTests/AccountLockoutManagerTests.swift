//
//  AccountLockoutManagerTests.swift
//  Systems InspectorTests
//
//  Unit tests for AccountLockoutManager
//  Created on 1/29/26.
//

import XCTest
@testable import Systems_Inspector

final class AccountLockoutManagerTests: XCTestCase {
    
    var sut: AccountLockoutManager!
    let testEmail = "test@example.com"
    
    override func setUp() {
        super.setUp()
        sut = AccountLockoutManager.shared
        
        // Clear any existing lockout data
        sut.manuallyUnlock(email: testEmail)
    }
    
    override func tearDown() {
        // Clean up after each test
        sut.manuallyUnlock(email: testEmail)
        sut = nil
        super.tearDown()
    }
    
    // MARK: - Initial State Tests
    
    func testAccountNotLockedInitially() {
        // Given: A fresh account with no failed attempts
        
        // When: Checking if account is locked
        let isLocked = sut.isAccountLocked(email: testEmail)
        
        // Then: Account should not be locked
        XCTAssertFalse(isLocked, "Account should not be locked initially")
    }
    
    func testInitialFailedAttemptsIsZero() {
        // Given: A fresh account
        
        // When: Getting failed attempts
        let attempts = sut.getFailedAttempts(email: testEmail)
        
        // Then: Should be zero
        XCTAssertEqual(attempts, 0, "Failed attempts should be zero initially")
    }
    
    func testInitialRemainingAttemptsFive() {
        // Given: A fresh account
        
        // When: Getting remaining attempts
        let remaining = sut.getRemainingAttempts(email: testEmail)
        
        // Then: Should be 5 (max attempts)
        XCTAssertEqual(remaining, 5, "Should have 5 attempts remaining initially")
    }
    
    // MARK: - Failed Attempt Tests
    
    func testRecordFailedAttemptIncrementsCounter() {
        // Given: A fresh account
        
        // When: Recording a failed attempt
        sut.recordFailedAttempt(email: testEmail)
        
        // Then: Failed attempts should be 1
        XCTAssertEqual(sut.getFailedAttempts(email: testEmail), 1)
    }
    
    func testMultipleFailedAttemptsIncrementCorrectly() {
        // Given: A fresh account
        
        // When: Recording 3 failed attempts
        for _ in 1...3 {
            sut.recordFailedAttempt(email: testEmail)
        }
        
        // Then: Should have 3 failed attempts
        XCTAssertEqual(sut.getFailedAttempts(email: testEmail), 3)
        XCTAssertEqual(sut.getRemainingAttempts(email: testEmail), 2)
    }
    
    func testAccountLockedAfterFiveFailedAttempts() {
        // Given: A fresh account
        
        // When: Recording 5 failed attempts
        for _ in 1...5 {
            sut.recordFailedAttempt(email: testEmail)
        }
        
        // Then: Account should be locked
        XCTAssertTrue(sut.isAccountLocked(email: testEmail), "Account should be locked after 5 attempts")
        XCTAssertEqual(sut.getRemainingAttempts(email: testEmail), 0)
    }
    
    // MARK: - Lockout Tests
    
    func testGetRemainingLockoutTimeWhenNotLocked() {
        // Given: An unlocked account
        
        // When: Getting remaining lockout time
        let remaining = sut.getRemainingLockoutTime(email: testEmail)
        
        // Then: Should be zero
        XCTAssertEqual(remaining, 0, "Lockout time should be zero when not locked")
    }
    
    func testGetRemainingLockoutTimeWhenLocked() {
        // Given: A locked account
        for _ in 1...5 {
            sut.recordFailedAttempt(email: testEmail)
        }
        
        // When: Getting remaining lockout time
        let remaining = sut.getRemainingLockoutTime(email: testEmail)
        
        // Then: Should be close to 15 minutes (900 seconds)
        XCTAssertGreaterThan(remaining, 890, "Lockout time should be around 15 minutes")
        XCTAssertLessThan(remaining, 910, "Lockout time should not exceed 15 minutes")
    }
    
    func testFormatRemainingTimeMinutes() {
        // Given: A time in seconds
        let seconds: TimeInterval = 90 // 1 minute 30 seconds
        
        // When: Formatting the time
        let formatted = sut.formatRemainingTime(seconds)
        
        // Then: Should be human readable
        XCTAssertEqual(formatted, "1 minute, 30 seconds")
    }
    
    func testFormatRemainingTimeSeconds() {
        // Given: Less than a minute
        let seconds: TimeInterval = 45
        
        // When: Formatting
        let formatted = sut.formatRemainingTime(seconds)
        
        // Then: Should show seconds only
        XCTAssertEqual(formatted, "45 seconds")
    }
    
    // MARK: - Successful Login Tests
    
    func testSuccessfulLoginClearsLockout() {
        // Given: Account with failed attempts
        for _ in 1...3 {
            sut.recordFailedAttempt(email: testEmail)
        }
        
        // When: Recording successful login
        sut.recordSuccessfulLogin(email: testEmail)
        
        // Then: Failed attempts should be cleared
        XCTAssertEqual(sut.getFailedAttempts(email: testEmail), 0)
        XCTAssertFalse(sut.isAccountLocked(email: testEmail))
    }
    
    func testSuccessfulLoginAfterLockoutClearsLockout() {
        // Given: A locked account
        for _ in 1...5 {
            sut.recordFailedAttempt(email: testEmail)
        }
        XCTAssertTrue(sut.isAccountLocked(email: testEmail))
        
        // When: Recording successful login
        sut.recordSuccessfulLogin(email: testEmail)
        
        // Then: Account should be unlocked
        XCTAssertFalse(sut.isAccountLocked(email: testEmail))
        XCTAssertEqual(sut.getFailedAttempts(email: testEmail), 0)
    }
    
    // MARK: - Manual Unlock Tests
    
    func testManualUnlockClearsLockout() {
        // Given: A locked account
        for _ in 1...5 {
            sut.recordFailedAttempt(email: testEmail)
        }
        XCTAssertTrue(sut.isAccountLocked(email: testEmail))
        
        // When: Manually unlocking
        sut.manuallyUnlock(email: testEmail)
        
        // Then: Account should be unlocked
        XCTAssertFalse(sut.isAccountLocked(email: testEmail))
        XCTAssertEqual(sut.getFailedAttempts(email: testEmail), 0)
    }
    
    // MARK: - Different Email Tests
    
    func testDifferentEmailsHaveSeparateLockouts() {
        // Given: Two different email accounts
        let email1 = "user1@example.com"
        let email2 = "user2@example.com"
        
        // When: One has failed attempts
        for _ in 1...3 {
            sut.recordFailedAttempt(email: email1)
        }
        
        // Then: Other should not be affected
        XCTAssertEqual(sut.getFailedAttempts(email: email1), 3)
        XCTAssertEqual(sut.getFailedAttempts(email: email2), 0)
        
        // Cleanup
        sut.manuallyUnlock(email: email1)
        sut.manuallyUnlock(email: email2)
    }
    
    // MARK: - Performance Tests
    
    func testPerformanceRecordingFailedAttempts() {
        measure {
            for _ in 1...100 {
                sut.recordFailedAttempt(email: "perf@test.com")
            }
            sut.manuallyUnlock(email: "perf@test.com")
        }
    }
    
    func testPerformanceCheckingLockoutStatus() {
        measure {
            for _ in 1...1000 {
                _ = sut.isAccountLocked(email: testEmail)
            }
        }
    }
}
