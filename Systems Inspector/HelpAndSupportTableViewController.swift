//
//  HelpAndSupportTableViewController.swift
//  Systems Inspector
//
//  Created by Eric Greska on 5/23/25.
//

import UIKit
import MessageUI // Needed for MFMailComposeViewControllerDelegate

class HelpAndSupportTableViewController: UITableViewController {

    private let helpItems = [
        "User Guide",
        "Frequently Asked Questions",
        "Troubleshooting",
        "About & Contact"
    ]

    // Delegate to communicate back to SettingsViewController for actions
    weak var settingsDelegate: SettingsActionsDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Help & Support"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "HelpCell")
        
        // Log screen view
        AnalyticsManager.shared.logScreenView(
            screenName: "Help & Support",
            screenClass: String(describing: type(of: self))
        )
    }

    // MARK: - UITableViewDataSource

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return helpItems.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "HelpCell", for: indexPath)
        cell.textLabel?.text = helpItems[indexPath.row]
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    // MARK: - UITableViewDelegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let contentVC: HelpContentViewController
        
        switch indexPath.row {
        case 0: // User Guide
            contentVC = HelpContentViewController(contentType: .userGuide)
            AnalyticsManager.shared.logEvent("help_user_guide_opened")
        case 1: // FAQs
            contentVC = HelpContentViewController(contentType: .faq)
            AnalyticsManager.shared.logEvent("help_faq_opened")
        case 2: // Troubleshooting
            contentVC = HelpContentViewController(contentType: .troubleshooting)
            AnalyticsManager.shared.logEvent("help_troubleshooting_opened")
        case 3: // About & Contact
            contentVC = HelpContentViewController(contentType: .about)
            AnalyticsManager.shared.logEvent("help_about_opened")
        default:
            return
        }
        
        navigationController?.pushViewController(contentVC, animated: true)
    }
}

// Define a delegate protocol for actions that need to be handled by SettingsViewController
protocol SettingsActionsDelegate: AnyObject {
    func showUserGuide()
    func showFAQs()
    func showContactSupport()
    func showReportBug()
}

// Extend HelpAndSupportTableViewController to conform to MFMailComposeViewControllerDelegate
extension HelpAndSupportTableViewController: MFMailComposeViewControllerDelegate {
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true)
    }
}
