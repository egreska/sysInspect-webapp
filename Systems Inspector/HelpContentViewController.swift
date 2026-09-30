//
//  HelpContentViewController.swift
//  Systems Inspector
//
//  Created by AI Assistant on 1/30/26.
//

import UIKit

class HelpContentViewController: UIViewController {
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let textView = UITextView()
    private let contentType: HelpContentType
    
    enum HelpContentType {
        case userGuide
        case faq
        case troubleshooting
        case about
    }
    
    init(contentType: HelpContentType) {
        self.contentType = contentType
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadContent()
        
        // Log screen view
        AnalyticsManager.shared.logScreenView(
            screenName: title ?? "Help Content",
            screenClass: String(describing: type(of: self))
        )
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        textView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(textView)
        
        // Configure text view
        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.font = .systemFont(ofSize: 16)
        textView.textColor = .label
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            textView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            textView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            textView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            textView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16)
        ])
    }
    
    private func loadContent() {
        let content: String
        
        switch contentType {
        case .userGuide:
            title = "User Guide"
            content = getUserGuideContent()
        case .faq:
            title = "FAQ"
            content = getFAQContent()
        case .troubleshooting:
            title = "Troubleshooting"
            content = getTroubleshootingContent()
        case .about:
            title = "About"
            content = getAboutContent()
        }
        
        // Create attributed string for better formatting
        let attributedString = NSMutableAttributedString(string: content)
        
        // Apply styles
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4
        paragraphStyle.paragraphSpacing = 12
        
        attributedString.addAttribute(
            .paragraphStyle,
            value: paragraphStyle,
            range: NSRange(location: 0, length: attributedString.length)
        )
        
        // Style headers (lines starting with #)
        let lines = content.components(separatedBy: .newlines)
        var currentPosition = 0
        
        for line in lines {
            let lineLength = line.count + 1 // +1 for newline
            
            if line.hasPrefix("# ") {
                // Main header
                let range = NSRange(location: currentPosition, length: min(lineLength - 1, attributedString.length - currentPosition))
                attributedString.addAttribute(.font, value: UIFont.boldSystemFont(ofSize: 24), range: range)
            } else if line.hasPrefix("## ") {
                // Subheader
                let range = NSRange(location: currentPosition, length: min(lineLength - 1, attributedString.length - currentPosition))
                attributedString.addAttribute(.font, value: UIFont.boldSystemFont(ofSize: 20), range: range)
            } else if line.hasPrefix("### ") {
                // Sub-subheader
                let range = NSRange(location: currentPosition, length: min(lineLength - 1, attributedString.length - currentPosition))
                attributedString.addAttribute(.font, value: UIFont.boldSystemFont(ofSize: 18), range: range)
            } else if line.hasPrefix("**") && line.hasSuffix("**") {
                // Bold text
                let range = NSRange(location: currentPosition, length: min(lineLength - 1, attributedString.length - currentPosition))
                attributedString.addAttribute(.font, value: UIFont.boldSystemFont(ofSize: 16), range: range)
            }
            
            currentPosition += lineLength
        }
        
        textView.attributedText = attributedString
    }
    
    // MARK: - Content Loading Methods
    // Keep these strings identical to HELP_AND_SUPPORT_CONTENT.md.

    private func getUserGuideContent() -> String {
        """
        # Pallet Rack Safety

        Pallet Rack Safety records customers, inspections, Issues, photos, and PDF or CSV reports. Data stays on this device and syncs to your iCloud account when iCloud sync is on.

        ## Account

        Create an account with your email, a password, and a security question. The password needs at least 8 characters, one uppercase letter, one lowercase letter, and one number.

        Log in with email and password. After a successful login on this device, the login screen can offer Face ID.

        Forgot Password asks for your email and security answer, then a new password.

        After 5 failed logins the account locks for 15 minutes. Wait, or use Forgot Password.

        ## Customers

        Open the Customers tab and tap + to add a customer. Search filters the list. The list loads 20 customers at a time.

        Open a customer to edit details, start an inspection, or open Site racking & documents.

        ## Inspections

        On a customer, tap New Inspection. For each location, enter Area/Aisle and, if you need it, Bay/Level. Tap Select Issue, then set Importance to Needs immediate attention or Monitor. Take Photo adds a photo. An item holds up to five photos. The button label changes to Add Photo after the first one. Save the item, then finish the inspection.

        ## Site racking and documents

        Site racking & documents is on the customer form and on the customer screen. It records installed equipment and up to five site documents (photos or PDFs). It is not an inspection and it is not an Issue.

        ## Reports

        Open the Reports tab. Select the inspections you want, then tap Generate PDF Report or Generate CSV Report. Share the file from the share sheet.

        ## Settings

        Inspector Name and Company Information are printed on reports. iCloud Sync shows the current sync status. Backup Data shares a copy of the database. Restore Data is not available in this version.

        Clear All Data deletes local data after you confirm it.

        Email support@skynet97.org for help.
        """
    }

    private func getFAQContent() -> String {
        """
        # Frequently Asked Questions

        ## Account

        **Can I use the app without an account?**
        No. Create an account on this device first.

        **What if I forget my password?**
        On the login screen, tap Forgot Password. You need the email and the security answer.

        **What if I forget the security answer?**
        This app cannot reset the account without that answer.

        **Can I change my email?**
        No. The email you used to create the account stays the login.

        ## Data

        **Where is my data stored?**
        On this device. When iCloud sync is on, inspection data also syncs to your iCloud account.

        **Does the app work offline?**
        You can keep working on this device. Sync runs when iCloud is available.

        **What if I delete the app?**
        The local copy is removed. Records already synced to your iCloud account can remain there. Restore Data in Settings is not available in this version.

        **How many photos can I add?**
        Up to five photos on an inspection item, and up to five site documents on a customer.

        ## Reports

        **How do I send a report?**
        Reports tab, select inspections, then Generate PDF Report or Generate CSV Report, then share.
        """
    }

    private func getTroubleshootingContent() -> String {
        """
        # Troubleshooting

        ## Can't log in

        Check the email and password, including capitals. Use Forgot Password if you know the security answer. If the account is locked, wait 15 minutes or use Forgot Password.

        ## Face ID does not appear

        Log in once with email and password on this device. Face ID is offered on the login screen after that, when the device has Face ID set up.

        ## Sync

        Settings → iCloud Sync shows the current status. If sync failed, tap the row for an explanation. Sign into iCloud in the iOS Settings app, check the network, then reopen Pallet Rack Safety.

        ## Photos

        Allow camera access when iOS asks. Inspection item photos come from the camera. Site documents can come from the camera, Photo Library, or Files. An inspection item holds up to five photos.

        ## Reports

        Select at least one inspection before you generate a PDF or CSV. If sharing fails, try saving to Files.

        ## Restore

        Settings → Restore Data is not available in this version. Backup Data can share a database copy. This version cannot load that file back in.
        """
    }

    private func getAboutContent() -> String {
        """
        # About

        Pallet Rack Safety records racking inspections: customers, Issues, photos, site racking, site documents, and PDF or CSV reports.

        The version number is on Settings → About.

        Support: support@skynet97.org

        © 2026 EKGDev. All rights reserved.
        """
    }
}
