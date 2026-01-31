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
        "Contact Support",
        "Report a Bug"
    ]

    // Delegate to communicate back to SettingsViewController for actions
    weak var settingsDelegate: SettingsActionsDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Help & Support"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "HelpCell")
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

        switch indexPath.row {
        case 0: // User Guide
            // Show user guide (e.g., present a web view or another VC)
            settingsDelegate?.showUserGuide()
        case 1: // FAQs
            // Show FAQs
            settingsDelegate?.showFAQs()
        case 2: // Contact Support
            settingsDelegate?.showContactSupport()
        case 3: // Report a Bug
            settingsDelegate?.showReportBug()
        default:
            break
        }
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
