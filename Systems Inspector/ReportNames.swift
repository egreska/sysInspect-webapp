import Foundation

struct ReportNames {
    static let shared = ReportNames(defaults: .standard)

    struct Company {
        var name: String?
        var street: String?
        var city: String?
        var state: String?
        var zip: String?
        var phone: String?
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func storedInspectorName() -> String? {
        defaults.string(forKey: Key.inspector)
    }

    func storedCompany() -> Company {
        Company(
            name: defaults.string(forKey: Key.companyName),
            street: defaults.string(forKey: Key.street),
            city: defaults.string(forKey: Key.city),
            state: defaults.string(forKey: Key.state),
            zip: defaults.string(forKey: Key.zip),
            phone: defaults.string(forKey: Key.phone)
        )
    }

    @discardableResult
    func saveInspectorName(_ raw: String) -> Bool {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return false }
        defaults.set(name, forKey: Key.inspector)
        return true
    }

    func saveCompany(name: String, street: String, city: String, state: String, zip: String, phone: String) {
        if !name.isEmpty {
            defaults.set(name, forKey: Key.companyName)
        }
        defaults.set(street, forKey: Key.street)
        defaults.set(city, forKey: Key.city)
        defaults.set(state, forKey: Key.state)
        defaults.set(zip, forKey: Key.zip)
        defaults.set(phone, forKey: Key.phone)
    }

    func header() -> ReportHeader {
        let company = storedCompany()
        return ReportHeader(
            companyName: company.name ?? "",
            companyAddress: company.street ?? "",
            companyPhone: company.phone ?? "",
            companyCity: company.city ?? "",
            companyState: company.state ?? "",
            companyZipCode: company.zip ?? "",
            inspectorName: storedInspectorName() ?? "Inspector Name"
        )
    }

    func settingsInspectorName() -> String {
        storedInspectorName() ?? "Not Set"
    }

    func settingsCompanyName() -> String {
        storedCompany().name ?? "Not Set"
    }

    func inspectorNameToStamp() -> String {
        storedInspectorName() ?? "Inspector Name"
    }

    func forget() {
        for key in Key.all {
            defaults.removeObject(forKey: key)
        }
    }

    private enum Key {
        static let inspector = "inspectorName"
        static let companyName = "companyName"
        static let street = "companyAddress"
        static let city = "companyCity"
        static let state = "companyState"
        static let zip = "companyZipCode"
        static let phone = "companyPhone"
        static let all = [inspector, companyName, street, city, state, zip, phone]
    }
}
