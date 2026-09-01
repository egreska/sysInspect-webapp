import XCTest
@testable import Systems_Inspector

final class UserManagerSessionTests: XCTestCase {

    private var isolated: SessionTestDefaults!

    override func setUp() {
        super.setUp()
        isolated = SessionTestDefaults()
        isolated.install()
    }

    override func tearDown() {
        isolated.uninstall()
        isolated = nil
        super.tearDown()
    }

    func testStartSessionSetsSessionAndLastUser() {
        let userId = UUID()
        UserManager.shared.startSession(userId: userId)
        XCTAssertEqual(UserManager.shared.sessionUserId, userId)
        XCTAssertEqual(UserManager.shared.lastUserId, userId)
        XCTAssertTrue(UserManager.shared.isUserLoggedIn())
    }

    func testLoggedInMeansSessionIdPresentWithoutLegacyFlags() {
        let userId = UUID()
        UserManager.shared.startSession(userId: userId)
        isolated.defaults.removeObject(forKey: "isLoggedIn")
        isolated.defaults.removeObject(forKey: "currentUserEmail")
        XCTAssertTrue(UserManager.shared.isUserLoggedIn())
        XCTAssertEqual(UserManager.shared.sessionUserId, userId)
    }

    func testUseHydratesSessionFromDefaults() {
        let userId = UUID()
        UserManager.shared.startSession(userId: userId)
        let empty = SessionTestDefaults()
        UserManager.shared.use(empty.defaults)
        XCTAssertNil(UserManager.shared.sessionUserId)
        XCTAssertFalse(UserManager.shared.isUserLoggedIn())
        UserManager.shared.use(isolated.defaults)
        empty.defaults.removePersistentDomain(forName: empty.suiteName)
        XCTAssertTrue(UserManager.shared.isUserLoggedIn())
        XCTAssertEqual(UserManager.shared.sessionUserId, userId)
    }

    func testLogoutClearsSessionAndKeepsLastUser() async {
        let userId = UUID()
        UserManager.shared.startSession(userId: userId)
        await UserManager.shared.logoutUser()
        XCTAssertNil(UserManager.shared.sessionUserId)
        XCTAssertFalse(UserManager.shared.isUserLoggedIn())
        XCTAssertEqual(UserManager.shared.lastUserId, userId)
    }

    func testWipeSessionClearsSessionAndLastUser() {
        let userId = UUID()
        UserManager.shared.startSession(userId: userId)
        UserManager.shared.wipeSession()
        XCTAssertNil(UserManager.shared.sessionUserId)
        XCTAssertNil(UserManager.shared.lastUserId)
        XCTAssertFalse(UserManager.shared.isUserLoggedIn())
    }

    func testStartSessionReplacesLastUser() async {
        let first = UUID()
        let second = UUID()
        UserManager.shared.startSession(userId: first)
        await UserManager.shared.logoutUser()
        UserManager.shared.startSession(userId: second)
        XCTAssertEqual(UserManager.shared.sessionUserId, second)
        XCTAssertEqual(UserManager.shared.lastUserId, second)
    }

    func testMigrateLegacyTripleToSessionAndLastUser() {
        let userId = UUID()
        isolated.defaults.set(true, forKey: "isLoggedIn")
        isolated.defaults.set("legacy@example.com", forKey: "currentUserEmail")
        isolated.defaults.set(userId.uuidString, forKey: "currentUserID")

        XCTAssertTrue(UserManager.shared.isUserLoggedIn())
        XCTAssertEqual(UserManager.shared.sessionUserId, userId)
        XCTAssertEqual(UserManager.shared.lastUserId, userId)
        XCTAssertNil(isolated.defaults.object(forKey: "isLoggedIn"))
        XCTAssertNil(isolated.defaults.object(forKey: "currentUserEmail"))
    }

    func testSuiteDoesNotWriteStandardDefaults() {
        let userId = UUID()
        UserManager.shared.startSession(userId: userId)
        XCTAssertNotEqual(
            UserDefaults.standard.string(forKey: "currentUserID"),
            userId.uuidString
        )
        XCTAssertNotEqual(
            UserDefaults.standard.string(forKey: "lastUserID"),
            userId.uuidString
        )
    }

    func testCompleteBiometricLoginFailsWithoutLastUser() {
        XCTAssertNil(UserManager.shared.lastUserId)
        XCTAssertFalse(UserManager.shared.completeBiometricLogin())
        XCTAssertNil(UserManager.shared.sessionUserId)
    }
}
