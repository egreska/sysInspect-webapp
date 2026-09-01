//
//  MainTabBarController.swift
//  Systems Inspector
//
//  Created by Eric Greska on 5/22/25.
//

import UIKit
import CoreData

class MainTabBarController: UITabBarController, UITabBarControllerDelegate, UINavigationControllerDelegate {
    
    private let syncIndicatorView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.tintColor = .systemGray
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.isAccessibilityElement = true
        iv.accessibilityLabel = "Sync status"
        return iv
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self
        setupTabBar()
        setupViewControllers()
        setupSyncIndicator()
        setupObservers()
        updateSyncIndicator()
    }
    
    private func setupSyncIndicator() {
        injectTitleViewWithSyncIndicator()
    }
    
    /// Creates a title view with sync indicator on the left and page title on the right.
    private func injectTitleViewWithSyncIndicator() {
        guard let nav = selectedViewController as? UINavigationController,
              let top = nav.topViewController else { return }
        let titleText = top.navigationItem.title ?? top.title ?? ""
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        let indicator = syncIndicatorView
        let titleLabel = UILabel()
        titleLabel.text = titleText
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = AppTheme.primaryContrast
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(indicator)
        container.addSubview(titleLabel)
        NSLayoutConstraint.activate([
            indicator.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            indicator.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            indicator.widthAnchor.constraint(equalToConstant: 22),
            indicator.heightAnchor.constraint(equalToConstant: 22),
            titleLabel.leadingAnchor.constraint(equalTo: indicator.trailingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        top.navigationItem.titleView = container
    }
    
    private func updateSyncIndicator() {
        applySyncIndicator(status: CoreDataManager.shared.currentCloudKitSyncStatus)
    }

    /// Applies icon and tint for the nav-bar sync glyph. Uses a single tint (no palette) to avoid heavy
    /// UIImageView / visual-effect paths that showed up in Crashlytics during CloudKit notifications.
    private func applySyncIndicator(status: CoreDataManager.CloudKitSyncStatus) {
        switch status {
        case .succeeded:
            syncIndicatorView.image = UIImage(systemName: "checkmark.icloud.fill")
            syncIndicatorView.tintColor = .systemGreen
            syncIndicatorView.accessibilityValue = "Synced"
        case .inProgress:
            syncIndicatorView.image = UIImage(systemName: "arrow.triangle.2.circlepath.icloud")
            syncIndicatorView.tintColor = .systemBlue
            syncIndicatorView.accessibilityValue = "Syncing"
        case .failed:
            syncIndicatorView.image = UIImage(systemName: "exclamationmark.icloud.fill")
            syncIndicatorView.tintColor = .systemOrange
            syncIndicatorView.accessibilityValue = "Sync paused"
        case .notStarted:
            syncIndicatorView.image = UIImage(systemName: "icloud")
            syncIndicatorView.tintColor = .systemGray
            syncIndicatorView.accessibilityValue = "Not started"
        }
    }
    
    private func setupObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(inspectionCompleted(_:)),
            name: .inspectionCompleted,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(cloudKitSyncStatusChanged(_:)),
            name: .cloudKitSyncStatusChanged,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(coreDataSaveDidFail(_:)),
            name: .coreDataSaveDidFail,
            object: nil
        )
    }
    
    @objc private func inspectionCompleted(_: Notification) {
        guard viewControllers?.count ?? 0 > 1 else { return }
        viewControllers?[1].tabBarItem.badgeValue = "New"
    }
    
    private var cloudKitWasPaused = false
    
    @objc private func cloudKitSyncStatusChanged(_ notification: Notification) {
        guard let status = notification.object as? CoreDataManager.CloudKitSyncStatus else { return }
        // Defer one turn so we are not updating UIImageView inside Core Data / NotificationCenter
        // call stacks that may still be visiting tint (Crashlytics: objc_loadWeak in _tintColorDidChange).
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.applySyncIndicator(status: status)
            if case .failed = status { self.cloudKitWasPaused = true }
            if case .succeeded = status, self.cloudKitWasPaused {
                self.cloudKitWasPaused = false
                let vc = (self.selectedViewController as? UINavigationController)?.topViewController ?? self.selectedViewController ?? self
                ToastView.show(on: vc, message: "Your data is now synced", duration: 2.5)
            }
        }
    }
    
    @objc private func coreDataSaveDidFail(_ notification: Notification) {
        let vc = (selectedViewController as? UINavigationController)?.topViewController ?? selectedViewController ?? self
        let alert = UIAlertController(
            title: "Save Failed",
            message: "Couldn't sync. Check iCloud in Settings to fix sync issues.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        })
        alert.addAction(UIAlertAction(title: "OK", style: .cancel))
        vc.present(alert, animated: true)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        injectTitleViewWithSyncIndicator()
        openPendingDeepLinkIfNeeded()
    }
    
    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        injectTitleViewWithSyncIndicator()
    }
    
    func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
        if navigationController.viewControllers.last === viewController {
            injectTitleViewWithSyncIndicator()
        }
    }
    
    private func openPendingDeepLinkIfNeeded() {
        guard let sceneDelegate = view.window?.windowScene?.delegate as? SceneDelegate,
              let customerId = sceneDelegate.consumePendingDeepLinkCustomerId() else {
            return
        }
        let context = CoreDataManager.shared.context
        guard let uuid = UUID(uuidString: customerId) else { return }
        let fetchRequest: NSFetchRequest<Customer> = Customer.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
        guard let customer = try? context.fetch(fetchRequest).first else { return }
        navigateToCustomerDetails(customer)
    }

    
    // MARK: - Setup
    private func setupTabBar() {
        tabBar.tintColor = AppTheme.primary
        tabBar.unselectedItemTintColor = AppTheme.textSecondary
        
        if #available(iOS 15.0, *) {
            let appearance = UITabBarAppearance()
            appearance.configureWithDefaultBackground()
            appearance.backgroundColor = .secondarySystemGroupedBackground
            appearance.backgroundEffect = UIBlurEffect(style: .systemChromeMaterial)
            
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
        customerDirectoryNav.tabBarItem.accessibilityLabel = "Customers"
        
        // Create reports tab
        let reportsVC = ReportViewController()
        let reportsNav = createNavigationController(
            rootViewController: reportsVC,
            title: "Reports",
            image: UIImage(systemName: "doc.text"),
            selectedImage: UIImage(systemName: "doc.text.fill")
        )
        reportsNav.tabBarItem.accessibilityLabel = "Reports"
        
        // Create settings tab
        let settingsVC = SettingsViewController()
        let settingsNav = createNavigationController(
            rootViewController: settingsVC,
            title: "Settings",
            image: UIImage(systemName: "gearshape"),
            selectedImage: UIImage(systemName: "gearshape.fill")
        )
        settingsNav.tabBarItem.accessibilityLabel = "Settings"
        
        // Set the view controllers
        viewControllers = [customerDirectoryNav, reportsNav, settingsNav]
        
        // Set the default selected tab
        selectedIndex = 0
    }
    
    private func createNavigationController(rootViewController: UIViewController, title: String, image: UIImage?, selectedImage: UIImage? = nil) -> UINavigationController {
        let navController = UINavigationController(rootViewController: rootViewController)
        navController.delegate = self
        
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
        navigationBar.prefersLargeTitles = false
        
        if #available(iOS 15.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = AppTheme.primary
            if let gradientImage = AppTheme.navigationBarGradientImage() {
                appearance.backgroundImage = gradientImage
            }
            appearance.titleTextAttributes = [.foregroundColor: AppTheme.primaryContrast]
            appearance.largeTitleTextAttributes = [.foregroundColor: AppTheme.primaryContrast]
            
            navigationBar.tintColor = AppTheme.primaryContrast
            navigationBar.standardAppearance = appearance
            navigationBar.scrollEdgeAppearance = appearance
            navigationBar.compactAppearance = appearance
        } else {
            navigationBar.barTintColor = AppTheme.primary
            navigationBar.tintColor = AppTheme.primaryContrast
            navigationBar.titleTextAttributes = [.foregroundColor: AppTheme.primaryContrast]
            navigationBar.largeTitleTextAttributes = [.foregroundColor: AppTheme.primaryContrast]
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
        let inspectionFormVC = InspectionItemFormViewController(viewModel: InspectionFormViewModel(existingInspection: inspection))
        navController.pushViewController(inspectionFormVC, animated: true)
    }
    
    /// Navigate to customer details
    func navigateToCustomerDetails(_ customer: Customer, showAddedToast: Bool = false) {
        // First switch to customers tab
        selectedIndex = 0

        // Get the navigation controller
        guard let navController = selectedViewController as? UINavigationController else { return }

        let customerDetailsVC = CustomerDetailsViewController(customer: customer)
        navController.pushViewController(customerDetailsVC, animated: true)
        if showAddedToast {
            ToastView.show(on: customerDetailsVC, message: "Customer added")
        }
    }
}
