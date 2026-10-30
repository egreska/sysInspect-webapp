//
//  AccessCodeGateTests.swift
//  Systems InspectorTests
//

import CloudKit
import XCTest
@testable import Systems_Inspector

@MainActor
final class AccessCodeGateTests: XCTestCase {
    private let pat = "pat-apple-id"
    private let coworker = "coworker-apple-id"
    private var suite: String!
    private var defaults: UserDefaults!
    private var cloud: ClaimCloudFake!
    private var state: ClaimGateState!
    private var check: ClaimCheck!

    override func setUp() async throws {
        try await super.setUp()
        suite = "si.claim.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        cloud = ClaimCloudFake()
        cloud.name = pat
        state = ClaimGateState()
        check = ClaimCheck(
            cloud: cloud,
            defaults: defaults,
            localUserCount: { [unowned self] in self.state.localUserCount },
            isLoggedIn: { [unowned self] in self.state.isLoggedIn },
            deleteUnfinished: { [unowned self] in self.state.deleteUnfinished }
        )
    }

    override func tearDown() async throws {
        check = nil
        defaults.removePersistentDomain(forName: suite)
        defaults = nil
        cloud = nil
        state = nil
        try await super.tearDown()
    }

    func testNormalizationStripsWhitespaceAndLowercases() {
        XCTAssertEqual(normalizedAccessCode("  AB CD\n"), "abcd")
        XCTAssertEqual(normalizedAccessCode(""), "")
    }

    func testIssuedCodeIsClaimedAndDoesNotMarkSessionReady() async {
        cloud.fetched = .issued

        let route = await check.check(code: "abc")

        XCTAssertEqual(route, .login(canCreateAccount: true))
        XCTAssertEqual(cloud.claims, [ClaimAttempt(code: "abc", user: pat)])
        XCTAssertEqual(cloud.marks, [])
        XCTAssertEqual(load(), CachedEntitlement(code: "abc", userRecordName: pat, sessionReady: false))
    }

    func testSameAppleIDOnAClaimedCodeIsAllowed() async {
        cloud.fetched = .claimed(userRecordName: pat, sessionReady: false)
        state.isLoggedIn = true

        let route = await check.check(code: "abc")

        XCTAssertEqual(route, .mainApp)
        XCTAssertEqual(cloud.claims, [] as [ClaimAttempt])
        XCTAssertEqual(cloud.marks, [])
    }

    func testOtherAppleIDIsRejectedAndDoesNotKeepThatCode() async {
        cloud.name = coworker
        cloud.fetched = .claimed(userRecordName: pat, sessionReady: true)
        seed(CachedEntitlement(code: "abc", userRecordName: coworker, sessionReady: false))

        let route = await check.check(code: "abc")

        XCTAssertEqual(route, .enterCode(.otherAppleID))
        XCTAssertNil(load())
        XCTAssertEqual(cloud.claims, [] as [ClaimAttempt])
    }

    func testRetiredCodeClearsTheCacheAndALaterCodeIsClaimed() async {
        cloud.fetched = .retired
        state.isLoggedIn = true
        seed(CachedEntitlement(code: "old", userRecordName: pat, sessionReady: true))

        let retired = await check.check(code: "old")

        XCTAssertEqual(retired, .enterCode(.retired))
        XCTAssertNil(load())
        XCTAssertEqual(cloud.claims, [] as [ClaimAttempt])

        cloud.fetched = .issued
        state.localUserCount = 1
        let replacement = await check.check(code: "new")

        XCTAssertEqual(replacement, .mainApp)
        XCTAssertEqual(cloud.claims, [ClaimAttempt(code: "new", user: pat)])
        XCTAssertEqual(cloud.marks, ["new"])
        XCTAssertEqual(load(), CachedEntitlement(code: "new", userRecordName: pat, sessionReady: true))
    }

    func testUnknownStringIsNotAnAccessCode() async {
        cloud.fetched = .missing

        let route = await check.check(code: "guess")

        XCTAssertEqual(route, .enterCode(.notIssued))
        XCTAssertNil(load())
        XCTAssertEqual(cloud.claims, [] as [ClaimAttempt])
    }

    func testSignedOutOfICloudHasNoInspector() async {
        cloud.reach = .signedOut
        seed(CachedEntitlement(code: "abc", userRecordName: pat, sessionReady: true))

        let route = await check.check(code: "abc")

        XCTAssertEqual(route, .signInToICloud)
        XCTAssertNil(load())
        XCTAssertEqual(cloud.fetchCount, 0)
    }

    func testTemporaryICloudFailureKeepsTheCachedClaim() async {
        XCTAssertEqual(accountCheck(from: .temporarilyUnavailable), .unknown)
        XCTAssertEqual(accountCheck(from: .couldNotDetermine), .unknown)
        XCTAssertEqual(accountCheck(from: .noAccount), .signedOut)
        XCTAssertEqual(accountCheck(from: .restricted), .signedOut)

        cloud.reach = .unknown
        cloud.name = nil
        cloud.fetched = .unreadable
        state.isLoggedIn = true
        state.localUserCount = 1
        let cache = CachedEntitlement(code: "abc", userRecordName: pat, sessionReady: true)
        seed(cache)

        let route = await check.check(code: nil)

        XCTAssertEqual(route, .mainApp)
        XCTAssertEqual(load(), cache)
        XCTAssertEqual(cloud.claims, [] as [ClaimAttempt])
    }

    func testTemporaryICloudFailureWithoutClaimNeedsNetwork() async {
        cloud.reach = .unknown
        cloud.name = nil

        let route = await check.check(code: nil)

        XCTAssertEqual(route, .needNetwork)
        XCTAssertNil(load())
    }

    func testOfflineCachedClaimKeepsWorking() async {
        cloud.fetched = .unreadable
        state.isLoggedIn = true
        state.localUserCount = 1
        let cache = CachedEntitlement(code: "abc", userRecordName: pat, sessionReady: true)
        seed(cache)

        let route = await check.check(code: nil)

        XCTAssertEqual(route, .mainApp)
        XCTAssertEqual(load(), cache)
        XCTAssertEqual(cloud.claims, [] as [ClaimAttempt])
    }

    func testOfflineFirstCheckNeedsNetwork() async {
        cloud.fetched = .unreadable

        let route = await check.check(code: "abc")

        XCTAssertEqual(route, .needNetwork)
        XCTAssertEqual(cloud.claims, [] as [ClaimAttempt])
    }

    func testMissingUserCountWaitsForTheSession() async {
        cloud.fetched = .claimed(userRecordName: pat, sessionReady: false)
        state.localUserCount = nil

        let route = await check.check(code: "abc")

        XCTAssertEqual(route, .waitingForSession)
        XCTAssertEqual(cloud.marks, [])
    }

    func testSecondDeviceWaitsForTheSession() async {
        cloud.fetched = .claimed(userRecordName: pat, sessionReady: true)

        let route = await check.check(code: "abc")

        XCTAssertEqual(route, .waitingForSession)
        XCTAssertEqual(cloud.claims, [] as [ClaimAttempt])
        XCTAssertEqual(cloud.marks, [])
    }

    func testUnfinishedDeleteHidesCreateAccount() async {
        state.deleteUnfinished = true
        cloud.fetched = .issued
        let cache = CachedEntitlement(code: "abc", userRecordName: pat, sessionReady: true)
        seed(cache)

        let route = await check.check(code: "abc")

        XCTAssertEqual(route, .deleteFinishing)
        XCTAssertEqual(load(), cache)
        XCTAssertEqual(cloud.claims, [] as [ClaimAttempt])
        XCTAssertEqual(cloud.marks, [])
    }

    func testFailedClaimUsesTheFreshRead() async {
        cloud.fetched = .issued
        seed(CachedEntitlement(code: "abc", userRecordName: pat, sessionReady: false))

        cloud.claimResult = .failed(.claimed(userRecordName: coworker, sessionReady: false))
        var route = await check.check(code: "abc")
        XCTAssertEqual(route, .enterCode(.otherAppleID))
        XCTAssertNil(load())
        XCTAssertEqual(cloud.marks, [])

        seed(CachedEntitlement(code: "abc", userRecordName: pat, sessionReady: false))
        cloud.claimResult = .failed(.retired)
        route = await check.check(code: "abc")
        XCTAssertEqual(route, .enterCode(.retired))
        XCTAssertNil(load())

        seed(CachedEntitlement(code: "abc", userRecordName: pat, sessionReady: false))
        cloud.claimResult = .failed(.missing)
        route = await check.check(code: "abc")
        XCTAssertEqual(route, .enterCode(.notIssued))
        XCTAssertNil(load())

        seed(CachedEntitlement(code: "abc", userRecordName: pat, sessionReady: false))
        cloud.claimResult = .failed(.unreadable)
        route = await check.check(code: "abc")
        XCTAssertEqual(route, .needNetwork)
        XCTAssertEqual(load()?.code, "abc")

        cloud.claimResult = .failed(.issued)
        route = await check.check(code: "abc")
        XCTAssertEqual(route, .needNetwork)
        XCTAssertEqual(load()?.code, "abc")
        XCTAssertEqual(cloud.marks, [])
    }

    func testDeletedSessionCanBeCreatedAgain() async {
        cloud.fetched = .claimed(userRecordName: pat, sessionReady: false)

        let route = await check.check(code: "abc")

        XCTAssertEqual(route, .login(canCreateAccount: true))
        XCTAssertEqual(cloud.marks, [])
    }

    func testLocalSessionHidesAccountCreationOnceTheMarkSucceeds() async {
        cloud.fetched = .claimed(userRecordName: pat, sessionReady: false)
        state.localUserCount = 1

        let route = await check.check(code: "abc")

        XCTAssertEqual(route, .login(canCreateAccount: false))
        XCTAssertEqual(cloud.marks, ["abc"])
        XCTAssertEqual(load()?.sessionReady, true)
    }

    func testFailedMarkStaysFalseUntilALaterCheck() async {
        cloud.fetched = .claimed(userRecordName: pat, sessionReady: false)
        cloud.markSucceeds = false
        state.localUserCount = 1
        state.isLoggedIn = true

        var route = await check.check(code: "abc")

        XCTAssertEqual(route, .mainApp)
        XCTAssertEqual(load()?.sessionReady, false)
        XCTAssertEqual(cloud.marks, ["abc"])

        cloud.markSucceeds = true
        route = await check.check(code: nil)

        XCTAssertEqual(route, .mainApp)
        XCTAssertEqual(load()?.sessionReady, true)
        XCTAssertEqual(cloud.marks, ["abc", "abc"])
    }

    func testSessionExistsMarksWithoutChangingTheCachedClaimWhenTheMarkFails() async {
        seed(CachedEntitlement(code: "abc", userRecordName: pat, sessionReady: false))
        cloud.markSucceeds = false

        await check.sessionExists()

        XCTAssertEqual(load()?.sessionReady, false)
        XCTAssertEqual(cloud.marks, ["abc"])
        XCTAssertEqual(cloud.fetchCount, 0)

        cloud.markSucceeds = true
        await check.sessionExists()

        XCTAssertEqual(load()?.sessionReady, true)
        XCTAssertEqual(cloud.fetchCount, 0)
    }

    func testDifferentAppleIDDoesNotReuseTheCachedCode() async {
        cloud.name = coworker
        seed(CachedEntitlement(code: "abc", userRecordName: pat, sessionReady: true))

        let route = await check.check(code: nil)

        XCTAssertEqual(route, .enterCode(nil))
        XCTAssertNil(load())
        XCTAssertEqual(cloud.fetchCount, 0)
    }

    func testLogoutUsesTheCachedClaimAndDoesNotFetchOrWrite() {
        seed(CachedEntitlement(code: "abc", userRecordName: pat, sessionReady: true))

        XCTAssertEqual(check.routeForLogout(), .waitingForSession)
        XCTAssertEqual(cloud.fetchCount, 0)
        XCTAssertEqual(cloud.claims, [] as [ClaimAttempt])
        XCTAssertEqual(cloud.marks, [])
    }

    private func seed(_ entitlement: CachedEntitlement) {
        let cache = AccessCodeCache(defaults: defaults)
        cache.save(entitlement)
    }

    private func load() -> CachedEntitlement? {
        AccessCodeCache(defaults: defaults).load()
    }
}

private struct ClaimAttempt: Equatable {
    var code: String
    var user: String
}

private final class ClaimGateState {
    var localUserCount: Int? = 0
    var isLoggedIn = false
    var deleteUnfinished = false
}

private final class ClaimCloudFake: AccessCodeCloudClient {
    var reach: AccountCheck = .signedIn
    var name: String?
    var fetched: AccessCodeRecordState = .issued
    var claimResult: ClaimResult = .accepted
    var markSucceeds = true
    var fetchCount = 0
    var claims: [ClaimAttempt] = []
    var marks: [String] = []

    func accountAvailable() async -> Bool { reach == .signedIn }

    func inspectorAccount() async -> AccountCheck { reach }

    func userRecordName() async -> String? { name }

    func fetch(code: String) async -> AccessCodeRecordState {
        fetchCount += 1
        return fetched
    }

    func claim(code: String, userRecordName: String) async -> ClaimResult {
        claims.append(ClaimAttempt(code: code, user: userRecordName))
        return claimResult
    }

    func markSessionReady(code: String) async -> Bool {
        marks.append(code)
        return markSucceeds
    }

    func clearSessionReady(code: String) async -> Bool { true }
}
