//
//  ClaimCheck.swift
//  Systems Inspector
//

import CoreData
import Foundation

@MainActor
final class ClaimCheck {
    static let shared = ClaimCheck(
        cloud: CloudKitAccessCodeClient(),
        defaults: .standard,
        localUserCount: {
            guard CoreDataManager.shared.isStoreLoaded else { return nil }
            let request: NSFetchRequest<User> = User.fetchRequest()
            return try? CoreDataManager.shared.context.count(for: request)
        },
        isLoggedIn: { UserManager.shared.isUserLoggedIn() },
        deleteUnfinished: { DeleteAccount.shared.isUnfinished }
    )

    private let cloud: AccessCodeCloudClient
    private let localUserCount: () -> Int?
    private let isLoggedIn: () -> Bool
    private let deleteUnfinished: () -> Bool
    private var cache: AccessCodeCache

    init(
        cloud: AccessCodeCloudClient,
        defaults: UserDefaults,
        localUserCount: @escaping () -> Int?,
        isLoggedIn: @escaping () -> Bool,
        deleteUnfinished: @escaping () -> Bool
    ) {
        self.cloud = cloud
        self.localUserCount = localUserCount
        self.isLoggedIn = isLoggedIn
        self.deleteUnfinished = deleteUnfinished
        self.cache = AccessCodeCache(defaults: defaults)
    }

    func check(code submittedCode: String?) async -> AccessRoute {
        let stored = cache.load()
        let reach = await cloud.inspectorAccount()
        let liveName = reach == .signedOut ? nil : await cloud.userRecordName()
        let account = accessAccount(reach: reach, liveUserRecordName: liveName, cache: stored)
        let userRecordName = account.userRecordName
        let matching = stored?.userRecordName == userRecordName ? stored : nil
        let code = submittedCode ?? matching?.code

        var reached = false
        var remote: AccessCodeRecordState?
        if let code, userRecordName != nil {
            let fetched = await cloud.fetch(code: code)
            if fetched == .unreadable {
                reached = false
                remote = nil
            } else {
                reached = true
                remote = fetched
            }
        }

        var resolution = resolveAccess(
            iCloudAvailable: account.iCloudAvailable,
            userRecordName: userRecordName,
            cache: stored,
            reachedCloudKit: reached,
            remote: remote,
            codeUnderCheck: code,
            localUserCount: localUserCount(),
            isLoggedIn: isLoggedIn(),
            deleteUnfinished: deleteUnfinished()
        )

        if resolution.writeClaim, let code, let userRecordName {
            if case .failed(let state) = await cloud.claim(code: code, userRecordName: userRecordName) {
                resolution = failedClaimResolution(
                    state: state,
                    userRecordName: userRecordName,
                    code: code,
                    cache: stored
                )
            }
        }

        if resolution.markSessionReady, let code = resolution.cache?.code {
            if await cloud.markSessionReady(code: code) {
                resolution.cache?.sessionReady = true
            } else {
                resolution.cache?.sessionReady = false
            }
        }

        cache.save(resolution.cache)
        return resolution.route
    }

    func sessionExists() async {
        guard var entitlement = cache.load() else { return }
        guard await cloud.markSessionReady(code: entitlement.code) else { return }
        entitlement.sessionReady = true
        cache.save(entitlement)
    }

    func routeForLogout() -> AccessRoute {
        loggedOutRoute(
            deleteUnfinished: deleteUnfinished(),
            localUserCount: localUserCount(),
            sessionReady: cache.load()?.sessionReady == true
        )
    }
}
