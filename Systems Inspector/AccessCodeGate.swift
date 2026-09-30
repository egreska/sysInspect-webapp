//
//  AccessCodeGate.swift
//  Systems Inspector
//

import Foundation

enum AccessCodeRecordState: Equatable {
    case missing
    case issued
    case claimed(userRecordName: String, sessionReady: Bool)
    case retired
    case unreadable
}

enum AccessCodeNotice: Equatable {
    case notIssued
    case otherAppleID
    case retired
}

enum AccessRoute: Equatable {
    case signInToICloud
    case needNetwork
    case enterCode(AccessCodeNotice?)
    case waitingForSession
    case login(canCreateAccount: Bool)
    case mainApp
}

struct CachedEntitlement: Equatable, Codable {
    var code: String
    var userRecordName: String
    var sessionReady: Bool
}

struct AccessResolution: Equatable {
    var route: AccessRoute
    var cache: CachedEntitlement?
    var writeClaim: Bool
    var markSessionReady: Bool
}

func normalizedAccessCode(_ raw: String) -> String {
    let stripped = raw.unicodeScalars.filter { !CharacterSet.whitespacesAndNewlines.contains($0) }
    return String(String.UnicodeScalarView(stripped)).lowercased()
}

func accessCodeGateBypassed() -> Bool {
    #if DEBUG
    return ProcessInfo.processInfo.arguments.contains("UI-Testing")
    #else
    return false
    #endif
}

func resolveAccess(
    iCloudAvailable: Bool,
    userRecordName: String?,
    cache: CachedEntitlement?,
    reachedCloudKit: Bool,
    remote: AccessCodeRecordState?,
    codeUnderCheck: String?,
    localUserCount: Int?,
    isLoggedIn: Bool
) -> AccessResolution {
    guard iCloudAvailable else {
        return AccessResolution(route: .signInToICloud, cache: nil, writeClaim: false, markSessionReady: false)
    }
    guard let userRecordName else {
        return AccessResolution(route: .needNetwork, cache: cache, writeClaim: false, markSessionReady: false)
    }

    let matchingCache = cache?.userRecordName == userRecordName ? cache : nil
    guard let code = codeUnderCheck, !code.isEmpty else {
        return AccessResolution(route: .enterCode(nil), cache: nil, writeClaim: false, markSessionReady: false)
    }

    guard reachedCloudKit, let remote else {
        if let matchingCache, matchingCache.code == code {
            return resolution(
                route: destination(
                    isLoggedIn: isLoggedIn,
                    localUserCount: localUserCount,
                    sessionReady: matchingCache.sessionReady
                ),
                cache: matchingCache,
                writeClaim: false,
                markSessionReady: false
            )
        }
        return AccessResolution(route: .needNetwork, cache: matchingCache, writeClaim: false, markSessionReady: false)
    }

    switch remote {
    case .missing:
        return AccessResolution(
            route: .enterCode(.notIssued),
            cache: matchingCache?.code == code ? nil : matchingCache,
            writeClaim: false,
            markSessionReady: false
        )
    case .retired:
        return AccessResolution(
            route: .enterCode(.retired),
            cache: matchingCache?.code == code ? nil : matchingCache,
            writeClaim: false,
            markSessionReady: false
        )
    case .unreadable:
        if let matchingCache, matchingCache.code == code {
            return resolution(
                route: destination(
                    isLoggedIn: isLoggedIn,
                    localUserCount: localUserCount,
                    sessionReady: matchingCache.sessionReady
                ),
                cache: matchingCache,
                writeClaim: false,
                markSessionReady: false
            )
        }
        return AccessResolution(route: .needNetwork, cache: matchingCache, writeClaim: false, markSessionReady: false)
    case .issued:
        let entitlement = CachedEntitlement(code: code, userRecordName: userRecordName, sessionReady: false)
        return resolution(
            route: destination(isLoggedIn: isLoggedIn, localUserCount: localUserCount, sessionReady: false),
            cache: entitlement,
            writeClaim: true,
            markSessionReady: (localUserCount ?? 0) > 0
        )
    case .claimed(let owner, let sessionReady):
        guard owner == userRecordName else {
            return AccessResolution(
                route: .enterCode(.otherAppleID),
                cache: matchingCache?.code == code ? nil : matchingCache,
                writeClaim: false,
                markSessionReady: false
            )
        }
        var entitlement = CachedEntitlement(code: code, userRecordName: userRecordName, sessionReady: sessionReady)
        let shouldMark = (localUserCount ?? 0) > 0 && !sessionReady
        if shouldMark {
            entitlement.sessionReady = true
        }
        return resolution(
            route: destination(isLoggedIn: isLoggedIn, localUserCount: localUserCount, sessionReady: entitlement.sessionReady),
            cache: entitlement,
            writeClaim: false,
            markSessionReady: shouldMark
        )
    }
}

private func destination(isLoggedIn: Bool, localUserCount: Int?, sessionReady: Bool) -> AccessRoute {
    if isLoggedIn {
        return .mainApp
    }
    guard let localUserCount else {
        return .waitingForSession
    }
    if localUserCount > 0 {
        return .login(canCreateAccount: false)
    }
    if sessionReady {
        return .waitingForSession
    }
    return .login(canCreateAccount: true)
}

private func resolution(
    route: AccessRoute,
    cache: CachedEntitlement?,
    writeClaim: Bool,
    markSessionReady: Bool
) -> AccessResolution {
    AccessResolution(route: route, cache: cache, writeClaim: writeClaim, markSessionReady: markSessionReady)
}

struct AccessCodeCache {
    static let storageKey = "accessCodeEntitlement"

    var defaults: UserDefaults

    func load() -> CachedEntitlement? {
        guard let data = defaults.data(forKey: Self.storageKey) else { return nil }
        return try? JSONDecoder().decode(CachedEntitlement.self, from: data)
    }

    func save(_ entitlement: CachedEntitlement?) {
        if let entitlement, let data = try? JSONEncoder().encode(entitlement) {
            defaults.set(data, forKey: Self.storageKey)
        } else {
            defaults.removeObject(forKey: Self.storageKey)
        }
    }
}
