//
//  SettingsUITests.swift
//  Systems InspectorUITests
//
//  UI tests for settings and data management
//  Created on 1/29/26.
//

import XCTest

final class SettingsUITests: XCTestCase {
    
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
    
    // MARK: - Settings Navigation Tests
    
    func testNavigateToSettings() {
        // Given: App launched
        
        // When: Navigating to settings tab
        if app.tabBars.buttons["Settings"].exists {
            app.tabBars.buttons["Settings"].tap()
            
            // Then: Settings screen should be visible
            XCTAssertTrue(app.navigationBars["Settings"].exists)
        }
    }
    
    func testSettingsSectionsExist() {
        // Given: Settings screen
        if app.tabBars.buttons["Settings"].exists {
            app.tabBars.buttons["Settings"].tap()
        }
        
        let table = app.tables.firstMatch
        
        // Then: Should have required sections
        XCTAssertTrue(table.exists)
        
        // Check for section headers
        XCTAssertTrue(table.staticTexts["Inspector Settings"].exists ||
                     table.cells["Inspector Name"].exists)
        XCTAssertTrue(table.staticTexts["Performance"].exists ||
                     table.cells["Clear Image Cache"].exists)
    }
    
    // MARK: - Performance Settings Tests
    
    func testClearImageCacheFlow() {
        // Given: Settings screen
        if app.tabBars.buttons["Settings"].exists {
            app.tabBars.buttons["Settings"].tap()
        }
        
        let table = app.tables.firstMatch
        let clearCacheCell = table.cells["Clear Image Cache"]
        
        if clearCacheCell.exists {
            // When: Tapping clear image cache
            clearCacheCell.tap()
            
            // Then: Should show confirmation alert
            let alert = app.alerts.firstMatch
            XCTAssertTrue(alert.waitForExistence(timeout: 5))
            XCTAssertTrue(alert.buttons["Cancel"].exists)
            XCTAssertTrue(alert.buttons["Clear Cache"].exists)
            
            // Cancel for test
            alert.buttons["Cancel"].tap()
        }
    }
    
    func testPerformanceStatsDisplay() {
        // Given: Settings screen
        if app.tabBars.buttons["Settings"].exists {
            app.tabBars.buttons["Settings"].tap()
        }
        
        let table = app.tables.firstMatch
        let statsCell = table.cells["Performance Stats"]
        
        if statsCell.exists {
            // When: Tapping performance stats
            statsCell.tap()
            
            // Then: Should show performance alert
            let alert = app.alerts["Performance Statistics"]
            XCTAssertTrue(alert.waitForExistence(timeout: 5))
            XCTAssertTrue(alert.buttons["Close"].exists || alert.buttons["Reset Stats"].exists)
            
            alert.buttons["Close"].tap()
        }
    }
    
    func testReleaseMemory() {
        // Given: Settings screen
        if app.tabBars.buttons["Settings"].exists {
            app.tabBars.buttons["Settings"].tap()
        }
        
        let table = app.tables.firstMatch
        let memoryCell = table.cells["Release Memory"]
        
        if memoryCell.exists {
            // When: Tapping release memory
            memoryCell.tap()
            
            // Then: Should show result alert
            let alert = app.alerts.firstMatch
            XCTAssertTrue(alert.waitForExistence(timeout: 5))
            XCTAssertTrue(alert.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Memory Released' OR label CONTAINS 'Freed'")).firstMatch.exists)
            
            alert.buttons["OK"].tap()
        }
    }
    
    // MARK: - Clear All Data Tests
    
    func testClearAllDataRequiresPassword() {
        // Given: Settings screen
        if app.tabBars.buttons["Settings"].exists {
            app.tabBars.buttons["Settings"].tap()
        }
        
        let table = app.tables.firstMatch
        let clearDataCell = table.cells["Clear All Data"]
        
        if clearDataCell.exists {
            // When: Tapping clear all data
            clearDataCell.tap()
            
            // Then: Should show warning
            var alert = app.alerts.firstMatch
            XCTAssertTrue(alert.waitForExistence(timeout: 5))
            XCTAssertTrue(alert.staticTexts.containing(NSPredicate(format: "label CONTAINS 'permanently'")).firstMatch.exists)
            
            // Proceed to password verification
            if alert.buttons["Clear All Data"].exists {
                alert.buttons["Clear All Data"].tap()
                
                // Should now show password prompt
                alert = app.alerts["Verify Identity"]
                XCTAssertTrue(alert.waitForExistence(timeout: 5))
                XCTAssertTrue(alert.secureTextFields["Password"].exists)
                XCTAssertTrue(alert.buttons["Verify"].exists)
                
                // Cancel for test safety
                alert.buttons["Cancel"].tap()
            } else {
                alert.buttons["Cancel"].tap()
            }
        }
    }
    
    func testClearAllDataCancelFlow() {
        // Given: Settings screen
        if app.tabBars.buttons["Settings"].exists {
            app.tabBars.buttons["Settings"].tap()
        }
        
        let table = app.tables.firstMatch
        let clearDataCell = table.cells["Clear All Data"]
        
        if clearDataCell.exists {
            // When: Starting clear all data and cancelling
            clearDataCell.tap()
            
            let alert = app.alerts.firstMatch
            XCTAssertTrue(alert.waitForExistence(timeout: 5))
            
            // Cancel at first step
            alert.buttons["Cancel"].tap()
            
            // Then: Should return to settings
            XCTAssertTrue(app.navigationBars["Settings"].exists)
            XCTAssertTrue(table.exists)
        }
    }
    
    // MARK: - Logout Tests
    
    func testLogoutConfirmation() {
        // Given: Settings screen
        if app.tabBars.buttons["Settings"].exists {
            app.tabBars.buttons["Settings"].tap()
        }
        
        let table = app.tables.firstMatch
        let logoutCell = table.cells["Logout"]
        
        if logoutCell.exists {
            // When: Tapping logout
            logoutCell.tap()
            
            // Then: Should show confirmation
            let alert = app.alerts["Logout"]
            XCTAssertTrue(alert.waitForExistence(timeout: 5))
            XCTAssertTrue(alert.buttons["Cancel"].exists)
            XCTAssertTrue(alert.buttons["Logout"].exists)
            
            // Cancel to stay in app
            alert.buttons["Cancel"].tap()
            
            // Should still be in settings
            XCTAssertTrue(app.navigationBars["Settings"].exists)
        }
    }
    
    // MARK: - Inspector Settings Tests
    
    func testInspectorNameSetting() {
        // Given: Settings screen
        if app.tabBars.buttons["Settings"].exists {
            app.tabBars.buttons["Settings"].tap()
        }
        
        let table = app.tables.firstMatch
        let nameCell = table.cells["Inspector Name"]
        
        if nameCell.exists {
            // When: Tapping inspector name
            nameCell.tap()
            
            // Then: Should show the padded inspector name editor
            let editor = app.navigationBars["Inspector Name"]
            XCTAssertTrue(editor.waitForExistence(timeout: 5))
            XCTAssertTrue(app.textFields["Your Name"].exists)
            
            editor.buttons["Cancel"].tap()
        }
    }
    
    // MARK: - Performance Tests
    
    func testSettingsScrollPerformance() {
        // Given: Settings screen
        if app.tabBars.buttons["Settings"].exists {
            app.tabBars.buttons["Settings"].tap()
        }
        
        let table = app.tables.firstMatch
        
        if table.exists {
            // When: Measuring scroll performance
            measure(metrics: [XCTOSSignpostMetric.scrollDecelerationMetric]) {
                table.swipeUp()
                table.swipeDown()
            }
        }
    }
}
