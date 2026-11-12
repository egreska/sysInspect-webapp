//
//  AppDelegate.swift
//  Systems Inspector
//
//  Created by Eric Greska on 5/22/25.
//

import UIKit
import CoreData
import FirebaseCore

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        // Configure Firebase
        FirebaseApp.configure()
        
        // Configure the appearance of the navigation bar
        configureAppearance()
        
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
        _ = CoreDataManager.shared.persistentContainer
        CoreDataManager.shared.checkCloudKitStatus()
        NotificationCenter.default.addObserver(
            forName: .coreDataStoreDidLoad,
            object: nil,
            queue: .main
        ) { _ in
            PasswordRecoveryManager.shared.adoptPhoneAnswers()
            DispatchQueue.global(qos: .utility).async {
                CoreDataManager.shared.migrateLocalPhotosToCloudKit()
            }
        }
    }
    
    // MARK: - UI Configuration
    
    private func configureAppearance() {
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = AppTheme.primary
        navAppearance.titleTextAttributes = [.foregroundColor: AppTheme.primaryContrast]
        navAppearance.largeTitleTextAttributes = [.foregroundColor: AppTheme.primaryContrast]
        
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        UINavigationBar.appearance().tintColor = AppTheme.primaryContrast
        
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithDefaultBackground()
        tabAppearance.backgroundColor = .secondarySystemGroupedBackground
        tabAppearance.backgroundEffect = UIBlurEffect(style: .systemChromeMaterial)
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
        UITabBar.appearance().tintColor = AppTheme.primary
        UITableView.appearance().separatorColor = AppTheme.separator
        UIButton.appearance(whenContainedInInstancesOf: [UINavigationBar.self]).tintColor = AppTheme.primaryContrast
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
