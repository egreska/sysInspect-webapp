//
//  SceneDelegate.swift
//  Systems Inspector
//
//  Created by Eric Greska on 5/22/25.
//
import UIKit
import CoreData

@available(iOS 13.0, *)
class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    
    /// When a customer deep link is received before login, store the customer ID and resolve after login.
    private var pendingDeepLinkCustomerId: String?
    
    /// Consumes and returns the pending customer deep link ID, if any. Call after login when main tab bar is shown.
    func consumePendingDeepLinkCustomerId() -> String? {
        let id = pendingDeepLinkCustomerId
        pendingDeepLinkCustomerId = nil
        return id
    }

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else {
            print("SceneDelegate: ERROR - Could not cast scene to UIWindowScene")
            return
        }
        
        print("SceneDelegate: Creating window with windowScene")
        
        // Create the window programmatically
        window = UIWindow(windowScene: windowScene)
        
        print("SceneDelegate: Window created: \(String(describing: window))")
        
        let splash = SplashViewController()
        splash.onComplete = { [weak self] in
            guard let self = self, let window = self.window else { return }
            let root: UIViewController
            if UserManager.shared.isUserLoggedIn() {
                root = MainTabBarController()
            } else {
                root = UINavigationController(rootViewController: LoginViewController())
            }
            UIView.transition(with: window, duration: 0.25, options: .transitionCrossDissolve) {
                window.rootViewController = root
            }
        }
        window?.rootViewController = splash
        print("SceneDelegate: Set root view controller to SplashViewController (0.3s brand moment)")
        
        window?.makeKeyAndVisible()
        print("SceneDelegate: Made window key and visible")
        
        print("SceneDelegate: Final window state - isHidden: \(window?.isHidden ?? true), isKeyWindow: \(window?.isKeyWindow ?? false)")
        
        // Handle any URLs that were passed to the app on launch
        if let urlContext = connectionOptions.urlContexts.first {
            handleIncomingURL(urlContext.url)
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
        
        // Save any unsaved data when the app is about to resign active
        CoreDataManager.shared.saveContext()
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
        
        // Save the context when entering background
        CoreDataManager.shared.saveContext()
    }
    
    // MARK: - URL Handling
    
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        handleIncomingURL(url)
    }
    
    private func handleIncomingURL(_ url: URL) {
        // Handle deep links or file opens
        
        // Example of handling a custom URL scheme (systemsinspector://customer/123)
        if url.scheme == "systemsinspector" {
            if url.host == "customer" {
                let customerId = url.lastPathComponent
                openCustomerDetails(with: customerId)
            }
        }
        
        // Example of handling a file open (e.g., a backup file)
        if url.pathExtension == "sibackup" {
            showRestoreDataPrompt(for: url)
        }
    }
    
    private func openCustomerDetails(with customerId: String) {
        // If we're still on login, store for after login
        guard window?.rootViewController is UITabBarController else {
            pendingDeepLinkCustomerId = customerId
            return
        }
        
        performOpenCustomerDetails(customerId: customerId)
    }
    
    private func performOpenCustomerDetails(customerId: String) {
        let context = CoreDataManager.shared.context
        
        guard let uuid = UUID(uuidString: customerId) else {
            print("Invalid customer ID format: \(customerId)")
            return
        }
        
        let fetchRequest: NSFetchRequest<Customer> = Customer.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
        
        do {
            let customers = try context.fetch(fetchRequest)
            guard let customer = customers.first else {
                print("Customer not found with ID: \(customerId)")
                return
            }
            
            guard let tabBarController = window?.rootViewController as? UITabBarController,
                  let viewControllers = tabBarController.viewControllers,
                  viewControllers.count > 0,
                  let navigationController = viewControllers[0] as? UINavigationController else {
                return
            }
            
            tabBarController.selectedIndex = 0
            let customerDetailsVC = CustomerDetailsViewController(customer: customer)
            navigationController.pushViewController(customerDetailsVC, animated: true)
        } catch {
            print("Error finding customer: \(error)")
        }
    }
    
    private func showRestoreDataPrompt(for url: URL) {
        let alert = UIAlertController(
            title: "Restore Backup",
            message: "Restore from backup is not available in this version.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        window?.rootViewController?.present(alert, animated: true)
    }
}
