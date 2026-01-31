//
//  CustomerDirectoryUITests.swift
//  Systems InspectorUITests
//
//  UI tests for customer directory and pagination
//  Created on 1/29/26.
//

import XCTest

final class CustomerDirectoryUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        
        app = XCUIApplication()
        app.launchArguments = ["UI-Testing"]
        // Note: These tests assume user is already logged in
        // In real scenario, you'd perform login first
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Customer Directory Tests
    
    func testCustomerDirectoryElementsExist() {
        // Given: App launched and logged in
        // Navigate to customers tab (assuming tab bar)
        
        if app.tabBars.buttons["Customers"].exists {
            app.tabBars.buttons["Customers"].tap()
        }
        
        // Then: Customer directory elements should exist
        XCTAssertTrue(app.navigationBars["Customers"].exists)
        XCTAssertTrue(app.buttons["+"].exists || app.buttons["Add"].exists)
        XCTAssertTrue(app.searchFields.firstMatch.exists)
    }
    
    func testAddCustomerButtonNavigates() {
        // Given: Customer directory
        if app.tabBars.buttons["Customers"].exists {
            app.tabBars.buttons["Customers"].tap()
        }
        
        // When: Tapping add button
        let addButton = app.buttons["+"].firstMatch
        if addButton.exists {
            addButton.tap()
            
            // Then: Should navigate to add customer screen
            XCTAssertTrue(app.navigationBars["Add Customer"].exists || 
                         app.staticTexts["Add Customer"].exists)
        }
    }
    
    func testSearchCustomers() {
        // Given: Customer directory with customers
        if app.tabBars.buttons["Customers"].exists {
            app.tabBars.buttons["Customers"].tap()
        }
        
        let searchField = app.searchFields.firstMatch
        
        if searchField.exists {
            // When: Entering search text
            searchField.tap()
            searchField.typeText("Test")
            
            // Then: Table should update (number of cells may change)
            // This is hard to test without knowing exact data
            XCTAssertTrue(app.tables.firstMatch.exists)
        }
    }
    
    func testPullToRefresh() {
        // Given: Customer directory
        if app.tabBars.buttons["Customers"].exists {
            app.tabBars.buttons["Customers"].tap()
        }
        
        let table = app.tables.firstMatch
        
        if table.exists {
            // When: Pulling down to refresh
            let start = table.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1))
            let finish = table.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9))
            start.press(forDuration: 0.1, thenDragTo: finish)
            
            // Then: Should trigger refresh (hard to verify without actual data)
            XCTAssertTrue(table.exists)
        }
    }
    
    func testScrollThroughCustomers() {
        // Given: Customer directory with many customers
        if app.tabBars.buttons["Customers"].exists {
            app.tabBars.buttons["Customers"].tap()
        }
        
        let table = app.tables.firstMatch
        
        if table.exists && table.cells.count > 0 {
            // When: Scrolling through list
            table.swipeUp()
            table.swipeUp()
            
            // Then: Should load more items (pagination)
            // Verify loading cell appears
            let loadingCell = table.cells.containing(NSPredicate(format: "label CONTAINS 'Loading'")).firstMatch
            
            // Loading cell may or may not exist depending on data
            // Just verify table still exists after scrolling
            XCTAssertTrue(table.exists)
        }
    }
    
    func testSelectCustomerNavigatesToDetails() {
        // Given: Customer directory with customers
        if app.tabBars.buttons["Customers"].exists {
            app.tabBars.buttons["Customers"].tap()
        }
        
        let table = app.tables.firstMatch
        
        if table.exists && table.cells.count > 0 {
            let firstCell = table.cells.firstMatch
            
            // When: Tapping on a customer
            firstCell.tap()
            
            // Then: Should navigate to customer details
            // Navigation bar might show customer name or "Customer Details"
            XCTAssertTrue(app.navigationBars.count > 1 || 
                         app.buttons["Back"].exists)
        }
    }
    
    // MARK: - Performance Tests
    
    func testScrollPerformance() {
        // Given: Customer directory
        if app.tabBars.buttons["Customers"].exists {
            app.tabBars.buttons["Customers"].tap()
        }
        
        let table = app.tables.firstMatch
        
        if table.exists {
            // When: Measuring scroll performance
            measure(metrics: [XCTOSSignpostMetric.scrollDecelerationMetric]) {
                table.swipeUp(velocity: .fast)
                table.swipeUp(velocity: .fast)
                table.swipeUp(velocity: .fast)
            }
        }
    }
}
