//
//  AccessCodeGateTests.swift
//  Systems InspectorTests
//

import CloudKit
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

    func testTemporaryICloudFailureKeepsTheCachedClaim() {
        XCTAssertEqual(accountCheck(from: .temporarilyUnavailable), .unknown)
        XCTAssertEqual(accountCheck(from: .couldNotDetermine), .unknown)
        XCTAssertEqual(accountCheck(from: .noAccount), .signedOut)
        XCTAssertEqual(accountCheck(from: .restricted), .signedOut)

        let cache = CachedEntitlement(code: "abc", userRecordName: pat, sessionReady: true)
        let account = accessAccount(reach: .unknown, liveUserRecordName: nil, cache: cache)
        XCTAssertTrue(account.iCloudAvailable)
        XCTAssertEqual(account.userRecordName, pat)

        let resolution = resolveAccess(
            iCloudAvailable: account.iCloudAvailable,
            userRecordName: account.userRecordName,
            cache: cache,
            reachedCloudKit: false,
            remote: nil,
            codeUnderCheck: cache.code,
            localUserCount: 1,
            isLoggedIn: true
        )
        XCTAssertEqual(resolution.route, .mainApp)
        XCTAssertEqual(resolution.cache, cache)
    }

    func testTemporaryICloudFailureWithoutClaimNeedsNetwork() {
        let account = accessAccount(reach: .unknown, liveUserRecordName: nil, cache: nil)
        XCTAssertTrue(account.iCloudAvailable)
        XCTAssertNil(account.userRecordName)

        let resolution = resolveAccess(
            iCloudAvailable: account.iCloudAvailable,
            userRecordName: account.userRecordName,
            cache: nil,
            reachedCloudKit: false,
            remote: nil,
            codeUnderCheck: nil,
            localUserCount: 0,
            isLoggedIn: false
        )
        XCTAssertEqual(resolution.route, .needNetwork)
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

    func testMissingUserCountWaitsForTheSession() {
        XCTAssertEqual(
            loggedOutRoute(deleteUnfinished: false, localUserCount: nil, sessionReady: false),
            .waitingForSession
        )
        let resolution = resolve(
            remote: .claimed(userRecordName: pat, sessionReady: false),
            code: "abc",
            user: pat,
            localUserCount: nil
        )
        XCTAssertEqual(resolution.route, .waitingForSession)
        XCTAssertFalse(resolution.markSessionReady)
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

    func testUnfinishedDeleteHidesCreateAccount() {
        let cache = CachedEntitlement(code: "abc", userRecordName: pat, sessionReady: true)
        let resolution = resolve(
            remote: .claimed(userRecordName: pat, sessionReady: true),
            code: "abc",
            user: pat,
            cache: cache,
            localUserCount: 0,
            deleteUnfinished: true
        )
        XCTAssertEqual(resolution.route, .deleteFinishing)
        XCTAssertFalse(resolution.markSessionReady)
        XCTAssertFalse(resolution.writeClaim)
        XCTAssertEqual(resolution.cache, cache)
    }

    func testFailedClaimUsesTheFreshRead() {
        let cache = CachedEntitlement(code: "abc", userRecordName: pat, sessionReady: false)
        let other = failedClaimResolution(
            state: .claimed(userRecordName: coworker, sessionReady: false),
            userRecordName: pat,
            code: "abc",
            cache: cache
        )
        XCTAssertEqual(other.route, .enterCode(.otherAppleID))
        XCTAssertNil(other.cache)

        let retired = failedClaimResolution(state: .retired, userRecordName: pat, code: "abc", cache: cache)
        XCTAssertEqual(retired.route, .enterCode(.retired))
        XCTAssertNil(retired.cache)

        let missing = failedClaimResolution(state: .missing, userRecordName: pat, code: "abc", cache: cache)
        XCTAssertEqual(missing.route, .enterCode(.notIssued))

        let dropped = failedClaimResolution(state: .unreadable, userRecordName: pat, code: "abc", cache: cache)
        XCTAssertEqual(dropped.route, .needNetwork)
        XCTAssertEqual(dropped.cache, cache)

        let stillIssued = failedClaimResolution(state: .issued, userRecordName: pat, code: "abc", cache: cache)
        XCTAssertEqual(stillIssued.route, .needNetwork)
        XCTAssertEqual(stillIssued.cache, cache)
    }

    func testExportBeforeTheDeleteDoesNotCount() {
        let savedAt = Date(timeIntervalSince1970: 1_000)
        XCTAssertFalse(exportCoversDelete(savedAt: savedAt, started: savedAt.addingTimeInterval(-1), ended: savedAt))
        XCTAssertFalse(exportCoversDelete(savedAt: savedAt, started: savedAt, ended: nil))
        XCTAssertTrue(exportCoversDelete(savedAt: savedAt, started: savedAt, ended: savedAt.addingTimeInterval(1)))
    }

    func testSessionReadyClearsOnlyWhenTheExportCoversTheDelete() {
        let savedAt = Date(timeIntervalSince1970: 1_000)
        XCTAssertFalse(deleteAccountExportCovers(
            savedAt: savedAt,
            exportStarted: savedAt.addingTimeInterval(-1),
            exportEnded: savedAt,
            exportFailed: false
        ))
        XCTAssertFalse(deleteAccountExportCovers(
            savedAt: savedAt,
            exportStarted: savedAt,
            exportEnded: savedAt.addingTimeInterval(1),
            exportFailed: true
        ))
        XCTAssertTrue(deleteAccountExportCovers(
            savedAt: savedAt,
            exportStarted: savedAt,
            exportEnded: savedAt.addingTimeInterval(1),
            exportFailed: false
        ))
        XCTAssertFalse(deleteAccountClearsSessionReady(exportCovers: false, clearSucceeded: true))
        XCTAssertFalse(deleteAccountClearsSessionReady(exportCovers: true, clearSucceeded: false))
        XCTAssertTrue(deleteAccountClearsSessionReady(exportCovers: true, clearSucceeded: true))
    }

    func testDeletedSessionCanBeCreatedAgain() {
        let resolution = resolve(
            remote: .claimed(userRecordName: pat, sessionReady: false),
            code: "abc",
            user: pat,
            localUserCount: 0
        )
        XCTAssertEqual(resolution.route, .login(canCreateAccount: true))
        XCTAssertFalse(resolution.markSessionReady)
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
        localUserCount: Int? = 0,
        isLoggedIn: Bool = false,
        deleteUnfinished: Bool = false
    ) -> AccessResolution {
        resolveAccess(
            iCloudAvailable: true,
            userRecordName: user,
            cache: cache,
            reachedCloudKit: reached,
            remote: remote,
            codeUnderCheck: code,
            localUserCount: localUserCount,
            isLoggedIn: isLoggedIn,
            deleteUnfinished: deleteUnfinished
        )
    }
}
