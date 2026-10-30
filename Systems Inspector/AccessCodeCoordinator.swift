//
//  AccessCodeCoordinator.swift
//  Systems Inspector
//

import UIKit

@MainActor
final class AccessCodeCoordinator {
    static let shared = AccessCodeCoordinator()

    private var checking = false
    private var pendingRecheck = false
    private var windowForRecheck: UIWindow?

    func showInitial(in window: UIWindow) async {
        windowForRecheck = window
        await DeleteAccount.shared.advance()
        let route = await ClaimCheck.shared.check(code: nil)
        apply(route, in: window, animated: true)
    }

    func recheck(in window: UIWindow) async {
        windowForRecheck = window
        guard !accessCodeGateBypassed() else { return }
        guard !(window.rootViewController is SplashViewController) else { return }
        guard !checking else {
            pendingRecheck = true
            return
        }
        checking = true
        defer {
            checking = false
            if pendingRecheck, let windowForRecheck {
                pendingRecheck = false
                Task { await self.recheck(in: windowForRecheck) }
            }
        }
        await DeleteAccount.shared.advance()
        let route = await ClaimCheck.shared.check(code: nil)
        apply(route, in: window, animated: false)
    }

    func submit(code rawCode: String, in window: UIWindow) async {
        let code = normalizedAccessCode(rawCode)
        guard !code.isEmpty else {
            show(AccessCodeViewController(route: .enterCode(.notIssued)), in: window, animated: false)
            return
        }
        guard !checking else { return }
        checking = true
        defer {
            checking = false
            if pendingRecheck, let windowForRecheck {
                pendingRecheck = false
                Task { await self.recheck(in: windowForRecheck) }
            }
        }
        let route = await ClaimCheck.shared.check(code: code)
        apply(route, in: window, animated: true)
    }

    func showLoggedOut(in window: UIWindow) {
        apply(ClaimCheck.shared.routeForLogout(), in: window, animated: true)
    }

    func makeBypassLoginViewController() -> LoginViewController {
        let controller = LoginViewController()
        controller.canCreateAccount = true
        return controller
    }

    private func apply(_ route: AccessRoute, in window: UIWindow, animated: Bool) {
        if let existing = window.rootViewController as? AccessCodeViewController {
            switch route {
            case .login, .mainApp:
                break
            default:
                existing.apply(route)
                return
            }
        }

        switch route {
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
        case .signInToICloud, .needNetwork, .enterCode, .waitingForSession, .deleteFinishing:
            show(AccessCodeViewController(route: route), in: window, animated: animated)
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
}
