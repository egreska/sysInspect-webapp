//
//  AccessCodeGateTests.swift
//  Systems InspectorTests
//

import XCTest
@testable import Systems_Inspector

final class AccessCodeGateTests: XCTestCase {

    private let pat = "pat-apple-id"
    private let coworker = "coworker-apple-id"

    func testNormalizationStripsWhitespaceAndLowercases() {
        XCTAssertEqual(normalizedAccessCode("  AB CD\n"), "abcd")
        XCTAssertEqual(normalizedAccessCode(""), "")
    }

    func testIssuedCodeIsClaimedByThisAppleID() {
        let resolution = resolve(
            remote: .issued,
            code: "abc",
            user: pat
        )
        XCTAssertEqual(resolution.route, .login(canCreateAccount: true))
        XCTAssertTrue(resolution.writeClaim)
        XCTAssertEqual(resolution.cache?.userRecordName, pat)
        XCTAssertEqual(resolution.cache?.sessionReady, false)
    }

    func testSameAppleIDOnAClaimedCodeIsAllowed() {
        let resolution = resolve(
            remote: .claimed(userRecordName: pat, sessionReady: false),
            code: "abc",
            user: pat,
            isLoggedIn: true
        )
        XCTAssertEqual(resolution.route, .mainApp)
        XCTAssertFalse(resolution.writeClaim)
    }

    func testOtherAppleIDIsRejectedAndDoesNotKeepThatCode() {
        let resolution = resolve(
            remote: .claimed(userRecordName: pat, sessionReady: true),
            code: "abc",
            user: coworker,
            cache: CachedEntitlement(code: "abc", userRecordName: coworker, sessionReady: false)
        )
        XCTAssertEqual(resolution.route, .enterCode(.otherAppleID))
        XCTAssertNil(resolution.cache)
    }

    func testRetiredCodeClearsTheCacheAndAcceptsALaterCode() {
        let retired = resolve(
            remote: .retired,
            code: "old",
            user: pat,
            cache: CachedEntitlement(code: "old", userRecordName: pat, sessionReady: true),
            isLoggedIn: true
        )
        XCTAssertEqual(retired.route, .enterCode(.retired))
        XCTAssertNil(retired.cache)

        let replacement = resolve(
            remote: .issued,
            code: "new",
            user: pat,
            isLoggedIn: true
        )
        XCTAssertEqual(replacement.route, .mainApp)
        XCTAssertTrue(replacement.writeClaim)
        XCTAssertEqual(replacement.cache?.code, "new")
    }

    func testUnknownStringIsNotAnAccessCode() {
        let resolution = resolve(remote: .missing, code: "guess", user: pat)
        XCTAssertEqual(resolution.route, .enterCode(.notIssued))
        XCTAssertNil(resolution.cache)
    }

    func testSignedOutOfICloudHasNoInspector() {
        let resolution = resolveAccess(
            iCloudAvailable: false,
            userRecordName: nil,
            cache: CachedEntitlement(code: "abc", userRecordName: pat, sessionReady: true),
            reachedCloudKit: false,
            remote: nil,
            codeUnderCheck: "abc",
            localUserCount: 1,
            isLoggedIn: true
        )
        XCTAssertEqual(resolution.route, .signInToICloud)
        XCTAssertNil(resolution.cache)
    }

    func testOfflineCachedClaimKeepsWorking() {
        let cache = CachedEntitlement(code: "abc", userRecordName: pat, sessionReady: true)
        let resolution = resolve(
            remote: nil,
            reached: false,
            code: "abc",
            user: pat,
            cache: cache,
            isLoggedIn: true
        )
        XCTAssertEqual(resolution.route, .mainApp)
        XCTAssertEqual(resolution.cache, cache)
    }

    func testOfflineFirstCheckNeedsNetwork() {
        let resolution = resolve(remote: nil, reached: false, code: "abc", user: pat)
        XCTAssertEqual(resolution.route, .needNetwork)
    }

    func testSecondDeviceWaitsForTheSession() {
        let resolution = resolve(
            remote: .claimed(userRecordName: pat, sessionReady: true),
            code: "abc",
            user: pat
        )
        XCTAssertEqual(resolution.route, .waitingForSession)
        XCTAssertFalse(resolution.writeClaim)
    }

    func testLocalSessionHidesAccountCreation() {
        let resolution = resolve(
            remote: .claimed(userRecordName: pat, sessionReady: false),
            code: "abc",
            user: pat,
            localUserCount: 1
        )
        XCTAssertEqual(resolution.route, .login(canCreateAccount: false))
        XCTAssertTrue(resolution.markSessionReady)
        XCTAssertEqual(resolution.cache?.sessionReady, true)
    }

    func testDifferentAppleIDDoesNotReuseTheCachedCode() {
        let resolution = resolveAccess(
            iCloudAvailable: true,
            userRecordName: coworker,
            cache: CachedEntitlement(code: "abc", userRecordName: pat, sessionReady: true),
            reachedCloudKit: false,
            remote: nil,
            codeUnderCheck: nil,
            localUserCount: 0,
            isLoggedIn: false
        )
        XCTAssertEqual(resolution.route, .enterCode(nil))
        XCTAssertNil(resolution.cache)
    }

    private func resolve(
        remote: AccessCodeRecordState?,
        reached: Bool = true,
        code: String,
        user: String,
        cache: CachedEntitlement? = nil,
        localUserCount: Int = 0,
        isLoggedIn: Bool = false
    ) -> AccessResolution {
        resolveAccess(
            iCloudAvailable: true,
            userRecordName: user,
            cache: cache,
            reachedCloudKit: reached,
            remote: remote,
            codeUnderCheck: code,
            localUserCount: localUserCount,
            isLoggedIn: isLoggedIn
        )
    }
}
