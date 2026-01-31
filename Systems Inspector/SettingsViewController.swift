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

    private let sections = ["Inspector Settings", "Application", "Data Management", "Performance"]
    private let sectionItems: [[String]] = [
        ["Inspector Name", "Company Information"],
        ["About", "Privacy Policy", "Help & Support"],
        ["Backup Data", "Restore Data", "Clear All Data", "Logout"],
        ["Clear Image Cache", "Performance Stats", "Release Memory"]
    ]

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Settings"
        view.backgroundColor = .systemBackground

        setupTableView()
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
    private func showInspectorNameSetting() {
        let alert = UIAlertController(
            title: "Inspector Name",
            message: "Enter your name to display on inspection reports",
            preferredStyle: .alert
        )

        alert.addTextField { textField in
            textField.placeholder = "Your Name"
            if let savedName = UserDefaults.standard.string(forKey: "inspectorName") {
                textField.text = savedName
            }
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            if let name = alert.textFields?.first?.text, !name.isEmpty {
                UserDefaults.standard.set(name, forKey: "inspectorName")
                self?.tableView.reloadData()
            }
        })

        present(alert, animated: true)
    }

    private func showCompanyInformationSetting() {
        let alert = UIAlertController(
            title: "Company Information",
            message: "Enter your company details to display on reports",
            preferredStyle: .alert
        )

        alert.addTextField { textField in
            textField.placeholder = "Company Name"
            if let savedName = UserDefaults.standard.string(forKey: "companyName") {
                textField.text = savedName
            }
        }

        alert.addTextField { textField in
            textField.placeholder = "Street Address"
            if let savedAddress = UserDefaults.standard.string(forKey: "companyAddress") {
                textField.text = savedAddress
            }
        }

        alert.addTextField { textField in
            textField.placeholder = "City"
            if let savedCity = UserDefaults.standard.string(forKey: "companyCity") {
                textField.text = savedCity
            }
        }

        alert.addTextField { textField in
            textField.placeholder = "State"
            if let savedState = UserDefaults.standard.string(forKey: "companyState") {
                textField.text = savedState
            }
        }

        alert.addTextField { textField in
            textField.placeholder = "ZIP Code"
            textField.keyboardType = .numberPad
            if let savedZip = UserDefaults.standard.string(forKey: "companyZipCode") {
                textField.text = savedZip
            }
        }

        alert.addTextField { textField in
            textField.placeholder = "Phone Number"
            textField.keyboardType = .phonePad
            if let savedPhone = UserDefaults.standard.string(forKey: "companyPhone") {
                textField.text = savedPhone
            }
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            if let companyName = alert.textFields?[0].text, !companyName.isEmpty {
                UserDefaults.standard.set(companyName, forKey: "companyName")
            }

            if let companyAddress = alert.textFields?[1].text {
                UserDefaults.standard.set(companyAddress, forKey: "companyAddress")
            }

            if let companyCity = alert.textFields?[2].text {
                UserDefaults.standard.set(companyCity, forKey: "companyCity")
            }

            if let companyState = alert.textFields?[3].text {
                UserDefaults.standard.set(companyState, forKey: "companyState")
            }

            if let companyZip = alert.textFields?[4].text {
                UserDefaults.standard.set(companyZip, forKey: "companyZipCode")
            }

            if let companyPhone = alert.textFields?[5].text {
                UserDefaults.standard.set(companyPhone, forKey: "companyPhone")
            }

            self?.tableView.reloadData()
        })

        present(alert, animated: true)
    }

    private func showAboutScreen() {
        let aboutVC = UIViewController()
        aboutVC.title = "About Rack Inspector"
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
        titleLabel.text = "Systems Inspector"
        titleLabel.font = UIFont.boldSystemFont(ofSize: 24)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)

        // Version label
        let versionLabel = UILabel()
        versionLabel.text = "Version 1.0"
        versionLabel.font = UIFont.systemFont(ofSize: 16)
        versionLabel.textAlignment = .center
        versionLabel.textColor = .secondaryLabel
        versionLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(versionLabel)

        // Description label
        let descriptionLabel = UILabel()
        descriptionLabel.text = """
        Systems Inspector is a comprehensive tool for warehouse racking inspections.
        It helps you maintain safety standards by providing a structured approach to inspecting, documenting, and reporting on the condition of warehouse racking systems.

        Features:
        • Customer management
        • Detailed inspections with photo documentation
        • Hierarchical damage reporting
        • PDF and CSV report generation
        • Data backup and restore

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
        Privacy Policy for Rack Inspector

        Last Updated: May 22, 2025

        1. Introduction

        This Privacy Policy describes how Rack Inspector collects, uses, and discloses your information when you use our mobile application.

        2. Information We Collect

        The app does not collect any personal information automatically. All data entered in the app (customer information, inspection details, photos) is stored locally on your device and is not transmitted to any external servers unless you explicitly choose to share reports via the sharing functionality.

        3. How We Use Your Information

        The information you enter is used solely for the purpose of generating inspection reports. No analytics or tracking is implemented in the app.

        4. Data Sharing and Disclosure

        We do not share your data with any third parties. When you generate reports and choose to share them, you control who receives those reports.

        5. Data Security

        We implement appropriate security measures to protect your data within the app. However, please be aware that no method of transmission or storage is 100% secure.

        6. Your Rights

        You have full control over all data in the app. You can delete any information at any time through the app's interface.

        7. Changes to This Privacy Policy

        We may update our Privacy Policy from time to time. Any changes will be reflected in the app with the updated "Last Updated" date.

        8. Contact Us

        If you have any questions about this Privacy Policy, please contact us at:

        Email: support@rackinspector.com
        """
        privacyTextView.font = UIFont.systemFont(ofSize: 16)
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
            mail.setSubject("Rack Inspector Support Request")
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
            mail.setSubject("Rack Inspector Bug Report")

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
        let alert = UIAlertController(
            title: "Restore Data",
            message: "To restore from a backup, you'll need to select a backup file. This will replace all current data and cannot be undone.",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        alert.addAction(UIAlertAction(title: "Select Backup File", style: .default) { [weak self] _ in
            self?.showDocumentPicker()
        })

        present(alert, animated: true)
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
            
            // Get current user email
            guard let email = UserDefaults.standard.string(forKey: "currentUserEmail") else {
                self?.showAlert(title: "Error", message: "No user is currently logged in.")
                return
            }
            
            // Verify password
            Task {
                let isValid = await UserManager.shared.authenticateUser(email: email, password: password)
                
                await MainActor.run {
                    if isValid {
                        print("✅ Password verified for data deletion")
                        // Password verified, proceed to final confirmation
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
        if settingName == "Inspector Name" {
            let inspectorName = UserDefaults.standard.string(forKey: "inspectorName") ?? "Not Set"
            cell.detailTextLabel?.text = inspectorName
            // FIXED: Show the actual saved name, not just "Not Set"
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

        // Attempt to restore from the selected backup file
        let alert = UIAlertController(
            title: "Confirm Restore",
            message: "Are you sure you want to restore from this backup? All current data will be replaced.",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        alert.addAction(UIAlertAction(title: "Restore", style: .destructive) { [weak self] _ in
            // Placeholder for restore functionality
            self?.showAlert(title: "Not Implemented", message: "Data restoration is not yet implemented.")
        })

        present(alert, animated: true)
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
