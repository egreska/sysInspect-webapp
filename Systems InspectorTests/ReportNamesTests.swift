import XCTest
@testable import Systems_Inspector

final class ReportNamesTests: XCTestCase {
    private var defaults: UserDefaults!
    private var names: ReportNames!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "ReportNamesTests")!
        defaults.removePersistentDomain(forName: "ReportNamesTests")
        names = ReportNames(defaults: defaults)
    }

    func testSaveReadsTheHeaderTheSettingsLineAndTheStamp() {
        XCTAssertTrue(names.saveInspectorName("  Pat Inspector  "))
        names.saveCompany(
            name: "  Rack Co  ",
            street: "1 Main",
            city: "Austin",
            state: "TX",
            zip: "78701",
            phone: "555"
        )

        let header = names.header()
        XCTAssertEqual(header.inspectorName, "Pat Inspector")
        XCTAssertEqual(header.companyName, "  Rack Co  ")
        XCTAssertEqual(header.companyAddress, "1 Main")
        XCTAssertEqual(header.companyCity, "Austin")
        XCTAssertEqual(header.companyState, "TX")
        XCTAssertEqual(header.companyZipCode, "78701")
        XCTAssertEqual(header.companyPhone, "555")
        XCTAssertEqual(names.settingsInspectorName(), "Pat Inspector")
        XCTAssertEqual(names.settingsCompanyName(), "  Rack Co  ")
        XCTAssertEqual(names.inspectorNameToStamp(), "Pat Inspector")
        XCTAssertEqual(names.storedInspectorName(), "Pat Inspector")
        XCTAssertEqual(names.storedCompany().name, "  Rack Co  ")
    }

    func testMissingNamesUseTheReportAndSettingsFallbacks() {
        let header = names.header()
        XCTAssertEqual(header.inspectorName, "Inspector Name")
        XCTAssertEqual(header.companyName, "")
        XCTAssertEqual(header.companyAddress, "")
        XCTAssertEqual(header.companyPhone, "")
        XCTAssertEqual(header.companyCity, "")
        XCTAssertEqual(header.companyState, "")
        XCTAssertEqual(header.companyZipCode, "")
        XCTAssertEqual(names.settingsInspectorName(), "Not Set")
        XCTAssertEqual(names.settingsCompanyName(), "Not Set")
        XCTAssertEqual(names.inspectorNameToStamp(), "Inspector Name")
        XCTAssertNil(names.storedInspectorName())
    }

    func testBlankInspectorNameLeavesTheStoredName() {
        XCTAssertTrue(names.saveInspectorName("Pat"))
        XCTAssertFalse(names.saveInspectorName("   "))
        XCTAssertEqual(names.storedInspectorName(), "Pat")
    }

    func testBlankCompanyNameLeavesTheStoredNameAndSavesTheRest() {
        names.saveCompany(name: "Rack Co", street: "1 Main", city: "Austin", state: "TX", zip: "78701", phone: "555")
        names.saveCompany(name: "", street: "", city: "Dallas", state: "", zip: "", phone: "")

        let company = names.storedCompany()
        XCTAssertEqual(company.name, "Rack Co")
        XCTAssertEqual(company.street, "")
        XCTAssertEqual(company.city, "Dallas")
        XCTAssertEqual(company.state, "")
        XCTAssertEqual(company.zip, "")
        XCTAssertEqual(company.phone, "")
        XCTAssertEqual(names.settingsCompanyName(), "Rack Co")
    }

    func testStoredEmptyNameStaysEmptyOnTheSettingsLine() {
        defaults.set("", forKey: "inspectorName")
        defaults.set("", forKey: "companyName")
        XCTAssertEqual(names.settingsInspectorName(), "")
        XCTAssertEqual(names.settingsCompanyName(), "")
        XCTAssertEqual(names.header().inspectorName, "")
        XCTAssertEqual(names.inspectorNameToStamp(), "")
    }

    func testForgetClearsTheNames() {
        XCTAssertTrue(names.saveInspectorName("Pat"))
        names.saveCompany(name: "Rack Co", street: "1 Main", city: "Austin", state: "TX", zip: "78701", phone: "555")

        names.forget()

        XCTAssertNil(names.storedInspectorName())
        XCTAssertNil(names.storedCompany().name)
        XCTAssertNil(names.storedCompany().street)
        XCTAssertNil(names.storedCompany().city)
        XCTAssertNil(names.storedCompany().state)
        XCTAssertNil(names.storedCompany().zip)
        XCTAssertNil(names.storedCompany().phone)
        XCTAssertEqual(names.settingsInspectorName(), "Not Set")
        XCTAssertEqual(names.header().inspectorName, "Inspector Name")
    }
}
