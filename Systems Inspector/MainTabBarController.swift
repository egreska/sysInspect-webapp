//
//  MainTabBarController.swift
//  Systems Inspector
//
//  Created by Eric Greska on 5/22/25.
//

import UIKit

class MainTabBarController: UITabBarController {
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        print("MainTabBarController: viewDidLoad called")
        setupTabBar()
        setupViewControllers()
        print("MainTabBarController: Setup completed")
    }

    
    // MARK: - Setup
    private func setupTabBar() {
        // Configure the tab bar appearance
        tabBar.tintColor = UIColor(red: 0.0, green: 0.4, blue: 0.8, alpha: 1.0)
        tabBar.unselectedItemTintColor = .darkGray
        
        if #available(iOS 15.0, *) {
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = .systemBackground
            
            tabBar.standardAppearance = appearance
            tabBar.scrollEdgeAppearance = appearance
        }
    }
    
    private func setupViewControllers() {
        // Create customer directory tab
        let customerDirectoryVC = CustomerDirectoryViewController()
        let customerDirectoryNav = createNavigationController(
            rootViewController: customerDirectoryVC,
            title: "Customers",
            image: UIImage(systemName: "person.3"),
            selectedImage: UIImage(systemName: "person.3.fill")
        )
        
        // Create reports tab
        let reportsVC = ReportViewController()
        let reportsNav = createNavigationController(
            rootViewController: reportsVC,
            title: "Reports",
            image: UIImage(systemName: "doc.text"),
            selectedImage: UIImage(systemName: "doc.text.fill")
        )
        
        // Create settings tab
        let settingsVC = SettingsViewController()
        let settingsNav = createNavigationController(
            rootViewController: settingsVC,
            title: "Settings",
            image: UIImage(systemName: "gearshape"),
            selectedImage: UIImage(systemName: "gearshape.fill")
        )
        
        // Set the view controllers
        viewControllers = [customerDirectoryNav, reportsNav, settingsNav]
        
        // Set the default selected tab
        selectedIndex = 0
    }
    
    private func createNavigationController(rootViewController: UIViewController, title: String, image: UIImage?, selectedImage: UIImage? = nil) -> UINavigationController {
        let navController = UINavigationController(rootViewController: rootViewController)
        
        // Configure navigation bar appearance
        configureNavigationBar(navController.navigationBar)
        
        // Set the tab bar item
        rootViewController.title = title
        navController.tabBarItem.title = title
        navController.tabBarItem.image = image
        
        if let selectedImage = selectedImage {
            navController.tabBarItem.selectedImage = selectedImage
        }
        
        return navController
    }
    
    private func configureNavigationBar(_ navigationBar: UINavigationBar) {
        // Configure the navigation bar appearance
        navigationBar.prefersLargeTitles = true
        
        if #available(iOS 15.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor(red: 0.0, green: 0.4, blue: 0.8, alpha: 1.0)
            appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
            appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
            
            navigationBar.tintColor = .white
            navigationBar.standardAppearance = appearance
            navigationBar.scrollEdgeAppearance = appearance
            navigationBar.compactAppearance = appearance
        } else {
            navigationBar.barTintColor = UIColor(red: 0.0, green: 0.4, blue: 0.8, alpha: 1.0)
            navigationBar.tintColor = .white
            navigationBar.titleTextAttributes = [.foregroundColor: UIColor.white]
            navigationBar.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        }
    }
    
    // MARK: - Public Methods
    
    /// Navigate to a specific tab
    func navigateToTab(_ index: Int) {
        guard index >= 0 && index < (viewControllers?.count ?? 0) else { return }
        selectedIndex = index
    }
    
    func navigateToResumeInspection(_ inspection: Inspection) {
        // First switch to customers tab
        selectedIndex = 0
        
        // Get the navigation controller
        guard let navController = selectedViewController as? UINavigationController else { return }
        
        // Create and push the inspection form configured for resuming
        let inspectionFormVC = InspectionFormViewController()
        inspectionFormVC.viewModel = InspectionFormViewModel(existingInspection: inspection)
        navController.pushViewController(inspectionFormVC, animated: true)
    }
    
    /// Navigate to customer details
    func navigateToCustomerDetails(_ customer: Customer) {
        // First switch to customers tab
        selectedIndex = 0

        // Get the navigation controller
        guard let navController = selectedViewController as? UINavigationController else { return }

        // Push the customer details view controller
        let customerDetailsVC = CustomerDetailsViewController(customer: customer)
        navController.pushViewController(customerDetailsVC, animated: true)
    }
}
