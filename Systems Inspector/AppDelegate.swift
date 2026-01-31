//
//  AppDelegate.swift
//  Systems Inspector
//
//  Created by Eric Greska on 5/22/25.
//

import UIKit
import CoreData
import Firebase

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        // Configure Firebase
        FirebaseApp.configure()
        
        // Configure the appearance of the navigation bar
        configureAppearance()
        
        // Initialize the main window if not using storyboards (iOS 12 and below)
        if #available(iOS 13.0, *) {
            // In iOS 13+ the SceneDelegate handles window setup
        } else {
            window = UIWindow(frame: UIScreen.main.bounds)
            // Go directly to LoginViewController - LaunchScreen.storyboard handles the splash
            let loginVC = LoginViewController()
            let navigationController = UINavigationController(rootViewController: loginVC)
            window?.rootViewController = navigationController
            window?.makeKeyAndVisible()
        }
        
        // Setup CoreData stack
        setupCoreData()
        
        return true
    }
    
    // MARK: - UISceneSession Lifecycle
    
    @available(iOS 13.0, *)
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
    
    @available(iOS 13.0, *)
    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
    
    // MARK: - Core Data
    
    private func setupCoreData() {
        // This will ensure Core Data is loaded before we need it
        _ = CoreDataManager.shared.context
        
        // Check CloudKit status
        CoreDataManager.shared.checkCloudKitStatus()
        
        // NEW: Migrate existing local photos to CloudKit
        DispatchQueue.global(qos: .background).async {
            CoreDataManager.shared.migrateLocalPhotosToCloudKit()
        }
        
        print("Core Data with CloudKit initialized successfully")
    }
    
    // MARK: - UI Configuration
    
    private func configureAppearance() {
        // Configure navigation bar appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 0.0, green: 0.4, blue: 0.8, alpha: 1.0)
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().tintColor = .white
        
        // Configure tab bar appearance
        UITabBar.appearance().tintColor = UIColor(red: 0.0, green: 0.4, blue: 0.8, alpha: 1.0)
        
        // Configure table view appearance
        UITableView.appearance().separatorColor = .lightGray
        
        // Configure button appearance
        UIButton.appearance(whenContainedInInstancesOf: [UINavigationBar.self]).tintColor = .white
    }
    
    // MARK: - Main Tab Bar Setup
    
    func createMainTabBarController() -> UITabBarController {
        let tabBarController = UITabBarController()
        
        // Create customer directory tab
        let customerDirectoryVC = CustomerDirectoryViewController()
        let customerDirectoryNav = UINavigationController(rootViewController: customerDirectoryVC)
        customerDirectoryNav.tabBarItem = UITabBarItem(
            title: "Customers",
            image: UIImage(systemName: "person.3"),
            tag: 0
        )
        
        // Create reports tab
        let reportsVC = ReportViewController()
        let reportsNav = UINavigationController(rootViewController: reportsVC)
        reportsNav.tabBarItem = UITabBarItem(
            title: "Reports",
            image: UIImage(systemName: "doc.text.chart"),
            tag: 1
        )
        
        // Create settings tab
        let settingsVC = SettingsViewController()
        let settingsNav = UINavigationController(rootViewController: settingsVC)
        settingsNav.tabBarItem = UITabBarItem(
            title: "Settings",
            image: UIImage(systemName: "gearshape"),
            tag: 2
        )
        
        // Set tabs
        tabBarController.viewControllers = [customerDirectoryNav, reportsNav, settingsNav]
        
        return tabBarController
    }
    
    // MARK: - App Lifecycle
    
    func applicationWillResignActive(_ application: UIApplication) {
        // Save any unsaved changes to CoreData
        CoreDataManager.shared.saveContext()
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        // Save context when entering background
        CoreDataManager.shared.saveContext()
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        // Save changes in the application's managed object context before the application terminates.
        CoreDataManager.shared.saveContext()
    }
}
