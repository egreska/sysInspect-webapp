import CoreSpotlight
import XCTest
@testable import Systems_Inspector

final class CustomerSearchIndexTests: XCTestCase {
    private let userId = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
    private let customerId = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!

    func testItemUsesNameAndSiteOnly() {
        let items = CustomerSearchIndex.items(
            entries: [SessionCustomerSearchEntry(id: customerId, name: "Acme", site: "Dock 4")],
            userId: userId
        )
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].uniqueIdentifier, "customer.\(customerId.uuidString)")
        XCTAssertEqual(items[0].domainIdentifier, "customer.\(userId.uuidString)")
        XCTAssertEqual(items[0].attributeSet.title, "Acme")
        XCTAssertEqual(items[0].attributeSet.displayName, "Acme")
        XCTAssertEqual(items[0].attributeSet.contentDescription, "Dock 4")
        XCTAssertNil(items[0].attributeSet.phoneNumbers)
        XCTAssertNil(items[0].attributeSet.supportsPhoneCall)
    }

    func testBlankNameIsOmittedAndBlankSiteHasNoDescription() {
        let items = CustomerSearchIndex.items(
            entries: [
                SessionCustomerSearchEntry(id: customerId, name: "  ", site: "Dock"),
                SessionCustomerSearchEntry(id: UUID(), name: "Beta", site: "  ")
            ],
            userId: userId
        )
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].attributeSet.title, "Beta")
        XCTAssertNil(items[0].attributeSet.contentDescription)
    }

    func testCustomerIdRoundTrip() {
        let identifier = CustomerSearchIndex.itemIdentifier(customerId: customerId)
        XCTAssertEqual(CustomerSearchIndex.customerId(from: identifier), customerId)
        XCTAssertNil(CustomerSearchIndex.customerId(from: "inspection.\(customerId.uuidString)"))
    }
}
