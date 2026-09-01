import Foundation
@testable import Systems_Inspector

struct SessionTestDefaults {
    let suiteName: String
    let defaults: UserDefaults

    init() {
        suiteName = "si.session.test.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
    }

    func install() {
        UserManager.shared.use(defaults)
    }

    func uninstall() {
        UserManager.shared.use(.standard)
        defaults.removePersistentDomain(forName: suiteName)
    }
}
