//
//  SettingsViewController.swift
//  Systems Inspector
//
//  Created by Eric Greska on 5/22/25.
//

import UIKit
import MessageUI // Keep this import for mail composer actions
import UniformTypeIdentifiers // For modern document picker

class SettingsViewController: UIViewController {

    // MARK: - Properties
    private let tableView = UITableView(frame: .zero, style: .grouped)

    private let sections = ["Sync", "Inspector Settings", "Application", "Data Management", "Performance"]
    private let sectionItems: [[String]] = [
        ["iCloud Sync"],
        ["Inspector Name", "Company Information"],
        ["About", "Privacy Policy", "Help & Support"],
        ["Backup Data", "Restore Data", "Clear All Data", "Logout"],
        ["Clear Image Cache", "Performance Stats", "Release Memory"]
    ]
    
    private var cloudKitSyncObserver: NSObjectProtocol?

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Settings"
        view.backgroundColor = .systemBackground

        setupTableView()
        cloudKitSyncObserver = NotificationCenter.default.addObserver(
            forName: .cloudKitSyncStatusChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.tableView.reloadData()
        }
    }
    
    deinit {
        if let observer = cloudKitSyncObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Setup
    private func setupTableView() {
        tableView.dataSource = self
        tableView.delegate = self
        tableView.translatesAutoresizingMaskIntoConstraints = false  // ADD THIS LINE
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "SettingCell")
    }

    // MARK: - Settings Actions
    private func showSyncErrorAlert() {
        let alert = UIAlertController(
            title: "Sync Paused",
            message: "Couldn't sync. Check iCloud in Settings to sign in or fix sync issues.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    private func showInspectorNameSetting() {
        presentInspectorForm(.inspectorName)
    }

    private func showCompanyInformationSetting() {
        presentInspectorForm(.companyInformation)
    }

    private func presentInspectorForm(_ form: InspectorSettingsFormViewController.Form) {
        let formVC = InspectorSettingsFormViewController(form: form) { [weak self] in
            self?.tableView.reloadData()
        }
        let navigationController = UINavigationController(rootViewController: formVC)
        if let sheet = navigationController.sheetPresentationController {
            switch form {
            case .inspectorName:
                sheet.detents = [.medium(), .large()]
                sheet.selectedDetentIdentifier = .medium
            case .companyInformation:
                sheet.detents = [.large()]
            }
            sheet.prefersGrabberVisible = true
        }
        present(navigationController, animated: true)
    }

    private func showAboutScreen() {
        let aboutVC = UIViewController()
        aboutVC.title = "About"
        aboutVC.view.backgroundColor = .systemBackground

        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        aboutVC.view.addSubview(scrollView)

        let contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)

        // App logo image view
        let logoImageView = UIImageView(image: UIImage(named: "AppIcon"))
        logoImageView.contentMode = .scaleAspectFit
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(logoImageView)

        // App title label
        let titleLabel = UILabel()
        titleLabel.text = "Pallet Rack Safety"
        titleLabel.font = .preferredFont(forTextStyle: .title1)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)

        // Version label
        let versionLabel = UILabel()
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        versionLabel.text = version.isEmpty ? "Version" : "Version \(version)"
        versionLabel.font = .preferredFont(forTextStyle: .body)
        versionLabel.adjustsFontForContentSizeCategory = true
        versionLabel.textAlignment = .center
        versionLabel.textColor = .secondaryLabel
        versionLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(versionLabel)

        // Description label
        let descriptionLabel = UILabel()
        descriptionLabel.text = """
        Pallet Rack Safety records warehouse racking inspections: customers, Issues, photos, site racking, site documents, and PDF or CSV reports.

        Features:
        • Customers and inspections
        • Issues, with up to five photos on each inspection item
        • Site racking and up to five site documents
        • PDF and CSV reports
        • Backup from Settings. Restore Data is not available in this version.

        © 2025 EKG Apps. All rights reserved.
        """
        descriptionLabel.numberOfLines = 0
        descriptionLabel.textAlignment = .left
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(descriptionLabel)

        // Set up constraints
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: aboutVC.view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: aboutVC.view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: aboutVC.view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: aboutVC.view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            logoImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            logoImageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            logoImageView.widthAnchor.constraint(equalToConstant: 100),
            logoImageView.heightAnchor.constraint(equalToConstant: 100),

            titleLabel.topAnchor.constraint(equalTo: logoImageView.bottomAnchor, constant: 20),
            titleLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

            versionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            versionLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

            descriptionLabel.topAnchor.constraint(equalTo: versionLabel.bottomAnchor, constant: 30),
            descriptionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            descriptionLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            descriptionLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])

        navigationController?.pushViewController(aboutVC, animated: true)
    }

    private func showPrivacyPolicy() {
        let privacyVC = UIViewController()
        privacyVC.title = "Privacy Policy"
        privacyVC.view.backgroundColor = .systemBackground

        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        privacyVC.view.addSubview(scrollView)

        let privacyTextView = UITextView()
        privacyTextView.isEditable = false
        privacyTextView.text = """
        Privacy Policy for Pallet Rack Safety

        Last Updated: September 27, 2026

        1. Introduction

        This Privacy Policy describes how Pallet Rack Safety handles information when you use the app.

        2. Information You Enter

        You enter account details, customers, inspections, Issues, photos, and site documents. The app stores a hash of your password on this device, not the password itself.

        3. Where Data Is Stored

        Inspection data is stored on your device. When iCloud sync is on, that data also syncs to your iCloud account. A report goes to whoever you send it to when you share it.

        4. Analytics

        When Firebase is enabled, the app can send crash and usage analytics. Analytics are separate from your inspection data.

        5. How Information Is Used

        Information you enter is used to manage inspections and generate reports.

        6. Data Security

        iCloud sync uses Apple's CloudKit. No method of storage or transmission is perfectly secure.

        7. Your Choices

        You can edit or delete customers, inspections, and photos in the app. Clear All Data in Settings removes local data after you confirm it.

        8. Changes to This Policy

        We may update this policy. The date above changes when we do.

        9. Contact

        Email: support@rackinspector.com
        """
        privacyTextView.font = .preferredFont(forTextStyle: .body)
        privacyTextView.adjustsFontForContentSizeCategory = true
        privacyTextView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(privacyTextView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: privacyVC.view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: privacyVC.view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: privacyVC.view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: privacyVC.view.bottomAnchor),

            privacyTextView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            privacyTextView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            privacyTextView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            privacyTextView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            privacyTextView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32)
        ])

        navigationController?.pushViewController(privacyVC, animated: true)
    }

    private func showHelpAndSupport() {
        let helpVC = HelpAndSupportTableViewController(style: .grouped) // Use the new dedicated class
        helpVC.settingsDelegate = self // Set self as the delegate
        navigationController?.pushViewController(helpVC, animated: true)
    }

    // These actions are now part of the SettingsActionsDelegate protocol
    // They are called by the HelpAndSupportTableViewController
    func showContactSupport() {
        if MFMailComposeViewController.canSendMail() {
            let mail = MFMailComposeViewController()
            mail.mailComposeDelegate = self
            mail.setToRecipients(["support@rackinspector.com"])
            mail.setSubject("Systems Inspector Support Request")
            mail.setMessageBody("Please describe your issue or question:", isHTML: false)
            present(mail, animated: true)
        } else {
            // Show fallback if mail is not available
            let alert = UIAlertController(
                title: "Email Not Available",
                message: "Please email your support request to support@rackinspector.com",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }

    func showReportBug() {
        if MFMailComposeViewController.canSendMail() {
            let mail = MFMailComposeViewController()
            mail.mailComposeDelegate = self
            mail.setToRecipients(["bugs@rackinspector.com"])
            mail.setSubject("Systems Inspector Bug Report")

            // Include device info and app version
            let deviceInfo = """


            --------------------
            Device: \(UIDevice.current.model)
            iOS Version: \(UIDevice.current.systemVersion)
            App Version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")
            """

            mail.setMessageBody("Please describe the bug and the steps to reproduce it:\n\n\(deviceInfo)", isHTML: false)
            present(mail, animated: true)
        } else {
            // Show fallback if mail is not available
            let alert = UIAlertController(
                title: "Email Not Available",
                message: "Please email your bug report to bugs@rackinspector.com",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }

    private func backupData() {
        if let backupURL = CoreDataManager.shared.backupDatabase() {
            let activityVC = UIActivityViewController(activityItems: [backupURL], applicationActivities: nil)
            present(activityVC, animated: true)
        } else {
            showAlert(title: "Backup Failed", message: "Unable to create a backup of the database.")
        }
    }

    private func restoreData() {
        showAlert(
            title: "Restore Data",
            message: "Restore from backup is not available in this version."
        )
    }

    private func showDocumentPicker() {
        let documentPicker: UIDocumentPickerViewController
        
        if #available(iOS 14.0, *) {
            // Use modern API for iOS 14+
            documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.data, .item])
        } else {
            // Fallback for older iOS versions
            documentPicker = UIDocumentPickerViewController(documentTypes: ["com.systemsinspector.backup", "public.data"], in: .import)
        }
        
        documentPicker.delegate = self
        documentPicker.allowsMultipleSelection = false
        present(documentPicker, animated: true)
    }

    private func clearImageCache() {
        // First, get the cache size
        ImageCacheManager.shared.getCacheSize { [weak self] size in
            let formattedSize = ImageCacheManager.shared.formatCacheSize(size)
            
            let alert = UIAlertController(
                title: "Clear Image Cache",
                message: "This will clear \(formattedSize) of cached images. Images will be reloaded from Core Data when needed.",
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            
            alert.addAction(UIAlertAction(title: "Clear Cache", style: .destructive) { _ in
                ImageCacheManager.shared.clearMemoryCache()
                ImageCacheManager.shared.clearDiskCache {
                    let successAlert = UIAlertController(
                        title: "Cache Cleared",
                        message: "Image cache has been successfully cleared.",
                        preferredStyle: .alert
                    )
                    successAlert.addAction(UIAlertAction(title: "OK", style: .default))
                    self?.present(successAlert, animated: true)
                }
            })
            
            self?.present(alert, animated: true)
        }
    }
    
    private func showPerformanceStats() {
        let summary = PerformanceOptimizer.shared.getPerformanceSummary()
        
        let alert = UIAlertController(
            title: "Performance Statistics",
            message: summary,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Reset Stats", style: .destructive) { _ in
            PerformanceOptimizer.shared.resetMetrics()
            let resetAlert = UIAlertController(
                title: "Stats Reset",
                message: "Performance statistics have been reset.",
                preferredStyle: .alert
            )
            resetAlert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(resetAlert, animated: true)
        })
        
        alert.addAction(UIAlertAction(title: "Close", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func releaseMemory() {
        let beforeMemory = PerformanceOptimizer.shared.getMemoryUsage()
        
        PerformanceOptimizer.shared.releaseUnusedResources()
        
        // Force garbage collection
        autoreleasepool {
            // Empty
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            let afterMemory = PerformanceOptimizer.shared.getMemoryUsage()
            let freed = beforeMemory.used - afterMemory.used
            
            let alert = UIAlertController(
                title: "Memory Released",
                message: "Freed \(String(format: "%.1f", max(0, freed)))MB\n\nBefore: \(String(format: "%.1f", beforeMemory.used))MB\nAfter: \(String(format: "%.1f", afterMemory.used))MB",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self?.present(alert, animated: true)
            
            // Reload table to update memory display
            self?.tableView.reloadData()
        }
    }
    
    private func clearAllData() {
        let alert = UIAlertController(
            title: "Clear All Data",
            message: "This will permanently delete all customers, inspections, and settings. This action cannot be undone.",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        alert.addAction(UIAlertAction(title: "Clear All Data", style: .destructive) { [weak self] _ in
            // Require password verification before proceeding
            self?.verifyPasswordForDataDeletion()
        })

        present(alert, animated: true)
    }

    private func showLogoutConfirmation() {
            let alert = UIAlertController(
                title: "Logout",
                message: "Are you sure you want to logout?",
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            
            alert.addAction(UIAlertAction(title: "Logout", style: .destructive) { _ in
                // Handle async logout call
                Task {
                    await UserManager.shared.logoutUser()
                    
                    // Ensure UI updates are on the main thread
                    await MainActor.run {
                        // Return to login screen
                        if let sceneDelegate = UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate,
                           let window = sceneDelegate.window {
                            let loginVC = LoginViewController()
                            let navigationController = UINavigationController(rootViewController: loginVC)
                            window.rootViewController = navigationController
                            UIView.transition(with: window, duration: 0.5, options: .transitionCrossDissolve, animations: nil, completion: nil)
                        }
                    }
                }
            })
            
            present(alert, animated: true)
        }
    
    private func verifyPasswordForDataDeletion() {
        let alert = UIAlertController(
            title: "Verify Identity",
            message: "Enter your password to authorize this critical operation.",
            preferredStyle: .alert
        )
        
        alert.addTextField { textField in
            textField.placeholder = "Password"
            textField.isSecureTextEntry = true
            textField.autocapitalizationType = .none
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
            self?.showAlert(title: "Cancelled", message: "Data deletion was cancelled.")
        })
        
        alert.addAction(UIAlertAction(title: "Verify", style: .default) { [weak self] _ in
            guard let password = alert.textFields?.first?.text, !password.isEmpty else {
                self?.showAlert(title: "Error", message: "Password is required to proceed.")
                return
            }
            
            Task {
                let isValid = await UserManager.shared.verifyCurrentUserPassword(password)
                
                await MainActor.run {
                    if isValid {
                        print("✅ Password verified for data deletion")
                        self?.confirmClearAllData()
                    } else {
                        print("❌ Invalid password for data deletion")
                        self?.showAlert(
                            title: "Authentication Failed",
                            message: "Invalid password. Data deletion cancelled for security."
                        )
                    }
                }
            }
        })
        
        present(alert, animated: true)
    }
    
    private func confirmClearAllData() {
        let alert = UIAlertController(
            title: "Final Confirmation",
            message: "Type DELETE in capital letters to permanently erase all data. This action cannot be undone.",
            preferredStyle: .alert
        )

        alert.addTextField { textField in
            textField.placeholder = "Type DELETE"
            textField.autocapitalizationType = .allCharacters
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
            self?.showAlert(title: "Cancelled", message: "Data deletion was cancelled.")
        })

        alert.addAction(UIAlertAction(title: "Delete All Data", style: .destructive) { [weak self] _ in
            guard let confirmText = alert.textFields?.first?.text, confirmText == "DELETE" else {
                self?.showAlert(title: "Cancelled", message: "Data deletion was cancelled. Confirmation text did not match.")
                return
            }

            print("🗑️ Performing data deletion...")

            UserManager.shared.wipeSession()
            
            // Perform the actual data deletion
            #if DEBUG
            CoreDataManager.shared.resetAllData()
            #endif

            // Clear user defaults
            let defaults = UserDefaults.standard
            let dictionary = defaults.dictionaryRepresentation()
            dictionary.keys.forEach { key in
                defaults.removeObject(forKey: key)
            }
            
            // Clear image cache
            ImageCacheManager.shared.clearMemoryCache()
            ImageCacheManager.shared.clearDiskCache {
                print("✅ All data cleared including caches")
            }
            
            // Clear performance cache
            PerformanceOptimizer.shared.releaseUnusedResources()

            self?.showAlert(title: "Data Cleared", message: "All data has been successfully deleted. Please restart the app.")
        })

        present(alert, animated: true)
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource
extension SettingsViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sectionItems[section].count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SettingCell", for: indexPath)
        let settingName = sectionItems[indexPath.section][indexPath.row]

        cell.textLabel?.text = settingName
        cell.accessoryType = .disclosureIndicator

        // Add detail text for certain settings
        if settingName == "iCloud Sync" {
            cell.detailTextLabel?.text = CoreDataManager.shared.currentCloudKitSyncStatus.displayString
            cell.accessoryType = .none
        } else if settingName == "Inspector Name" {
            let inspectorName = UserDefaults.standard.string(forKey: "inspectorName") ?? "Not Set"
            cell.detailTextLabel?.text = inspectorName
        } else if settingName == "Company Information" {
            cell.detailTextLabel?.text = UserDefaults.standard.string(forKey: "companyName") ?? "Not Set"
        }

        // Customize appearance for Clear All Data
        if settingName == "Clear All Data" {
            cell.textLabel?.textColor = .systemRed
        } else {
            cell.textLabel?.textColor = .label // Reset color for other cells
        }
        
        // Show cache size for Clear Image Cache
        if settingName == "Clear Image Cache" {
            // Get cache size asynchronously
            ImageCacheManager.shared.getCacheSize { size in
                DispatchQueue.main.async {
                    cell.detailTextLabel?.text = ImageCacheManager.shared.formatCacheSize(size)
                }
            }
        } else if settingName == "Performance Stats" {
            let memory = PerformanceOptimizer.shared.getMemoryUsage()
            cell.detailTextLabel?.text = "\(String(format: "%.1f", memory.used))MB"
        }
        
        if settingName != "iCloud Sync" {
            cell.accessoryType = .disclosureIndicator
        }

        return cell
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section]
    }
}

// MARK: - UITableViewDelegate
extension SettingsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let settingName = sectionItems[indexPath.section][indexPath.row]

        switch settingName {
        case "iCloud Sync":
            if case .failed = CoreDataManager.shared.currentCloudKitSyncStatus {
                showSyncErrorAlert()
            }
            break
        case "Inspector Name":
            showInspectorNameSetting()
        case "Company Information":
            showCompanyInformationSetting()
        case "About":
            showAboutScreen()
        case "Privacy Policy":
            showPrivacyPolicy()
        case "Help & Support":
            showHelpAndSupport() // This calls the function with the new VC
        case "Backup Data":
            backupData()
        case "Restore Data":
            restoreData()
        case "Clear All Data":
            clearAllData()
        case "Logout":
            showLogoutConfirmation()
        case "Clear Image Cache":
            clearImageCache()
        case "Performance Stats":
            showPerformanceStats()
        case "Release Memory":
            releaseMemory()
        default:
            break
        }
    }
}

// MARK: - UIDocumentPickerDelegate
extension SettingsViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard urls.first != nil else { return }
        showAlert(
            title: "Restore Data",
            message: "Restore from backup is not available in this version."
        )
    }
}

// MARK: - MFMailComposeViewControllerDelegate (Moved here from HelpAndSupportTableViewController.swift)
extension SettingsViewController: MFMailComposeViewControllerDelegate {
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true)
    }
}

// MARK: - SettingsActionsDelegate (New extension)
extension SettingsViewController: SettingsActionsDelegate {
    func showUserGuide() {
        // Implement navigation or presentation of User Guide
        showAlert(title: "User Guide", message: "User Guide functionality not yet implemented.")
    }

    func showFAQs() {
        // Implement navigation or presentation of FAQs
        showAlert(title: "FAQs", message: "Frequently Asked Questions functionality not yet implemented.")
    }
    // showContactSupport() and showReportBug() are already defined above and are now part of this conformance.
}
