//
//  AccessCodeCoordinator.swift
//  Systems Inspector
//

import CoreData
import UIKit

@MainActor
final class AccessCodeCoordinator {
    static let shared = AccessCodeCoordinator()

    private let cloud: AccessCodeCloudClient
    private var cache: AccessCodeCache
    private var checking = false

    init(cloud: AccessCodeCloudClient = CloudKitAccessCodeClient(), defaults: UserDefaults = .standard) {
        self.cloud = cloud
        self.cache = AccessCodeCache(defaults: defaults)
    }

    func showInitial(in window: UIWindow) async {
        let resolution = await evaluate(submittedCode: nil)
        apply(resolution, in: window, animated: true)
    }

    func recheck(in window: UIWindow) async {
        guard !accessCodeGateBypassed() else { return }
        guard !(window.rootViewController is SplashViewController) else { return }
        guard !checking else { return }
        let resolution = await evaluate(submittedCode: nil)
        apply(resolution, in: window, animated: false)
    }

    func submit(code rawCode: String, in window: UIWindow) async {
        let code = normalizedAccessCode(rawCode)
        guard !code.isEmpty else {
            show(AccessCodeViewController(route: .enterCode(.notIssued)), in: window, animated: false)
            return
        }
        guard !checking else { return }
        let resolution = await evaluate(submittedCode: code)
        apply(resolution, in: window, animated: true)
    }

    func markSessionReady() async {
        guard var entitlement = cache.load() else { return }
        guard await cloud.markSessionReady(code: entitlement.code) else { return }
        entitlement.sessionReady = true
        cache.save(entitlement)
    }

    func makeLoginViewController() -> LoginViewController {
        let controller = LoginViewController()
        if accessCodeGateBypassed() {
            controller.canCreateAccount = true
            return controller
        }
        let count = (try? CoreDataManager.shared.context.count(for: User.fetchRequest())) ?? 0
        let sessionReady = cache.load()?.sessionReady == true
        controller.canCreateAccount = count == 0 && !sessionReady
        return controller
    }

    private func evaluate(submittedCode: String?) async -> AccessResolution {
        checking = true
        defer { checking = false }

        let iCloudAvailable = await cloud.accountAvailable()
        let userRecordName = iCloudAvailable ? await cloud.userRecordName() : nil
        let stored = cache.load()
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
            iCloudAvailable: iCloudAvailable,
            userRecordName: userRecordName,
            cache: stored,
            reachedCloudKit: reached,
            remote: remote,
            codeUnderCheck: code,
            localUserCount: localUserCount(),
            isLoggedIn: UserManager.shared.isUserLoggedIn()
        )

        if resolution.writeClaim, let code, let userRecordName {
            let wrote = await cloud.claim(code: code, userRecordName: userRecordName)
            if !wrote {
                resolution = AccessResolution(
                    route: .enterCode(.otherAppleID),
                    cache: matching?.code == code ? nil : matching,
                    writeClaim: false,
                    markSessionReady: false
                )
            }
        }

        if resolution.markSessionReady, let code = resolution.cache?.code {
            if await cloud.markSessionReady(code: code) {
                resolution.cache?.sessionReady = true
            } else {
                resolution.cache?.sessionReady = false
                resolution.markSessionReady = false
            }
        }

        cache.save(resolution.cache)
        return resolution
    }

    private func apply(_ resolution: AccessResolution, in window: UIWindow, animated: Bool) {
        if let existing = window.rootViewController as? AccessCodeViewController {
            switch resolution.route {
            case .login, .mainApp:
                break
            default:
                existing.apply(resolution.route)
                return
            }
        }

        switch resolution.route {
        case .mainApp:
            guard !(window.rootViewController is MainTabBarController) else { return }
            show(MainTabBarController(), in: window, animated: animated)
        case .login(let canCreateAccount):
            if let navigation = window.rootViewController as? UINavigationController,
               let login = navigation.viewControllers.first as? LoginViewController,
               navigation.viewControllers.count == 1 {
                login.canCreateAccount = canCreateAccount
                return
            }
            let login = LoginViewController()
            login.canCreateAccount = canCreateAccount
            show(UINavigationController(rootViewController: login), in: window, animated: animated)
        case .signInToICloud, .needNetwork, .enterCode, .waitingForSession:
            show(AccessCodeViewController(route: resolution.route), in: window, animated: animated)
        }
    }

    private func show(_ controller: UIViewController, in window: UIWindow, animated: Bool) {
        guard animated else {
            window.rootViewController = controller
            return
        }
        UIView.transition(with: window, duration: 0.25, options: .transitionCrossDissolve) {
            window.rootViewController = controller
        }
    }

    private func localUserCount() -> Int? {
        guard CoreDataManager.shared.isStoreLoaded else { return nil }
        let request: NSFetchRequest<User> = User.fetchRequest()
        return try? CoreDataManager.shared.context.count(for: request)
    }
}
