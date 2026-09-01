//
//  ReportShareActivities.swift
//  Systems Inspector
//
//  Custom share sheet activities: Copy summary, Email report.
//

import UIKit
import MessageUI

final class CopySummaryActivity: UIActivity {
    static let typeId = "com.systemsinspector.copy-summary"
    
    private var summaryText: String?
    
    override var activityType: UIActivity.ActivityType? {
        UIActivity.ActivityType(rawValue: Self.typeId)
    }
    
    override var activityTitle: String? { "Copy summary" }
    override var activityImage: UIImage? { UIImage(systemName: "doc.on.clipboard") }
    
    override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
        activityItems.contains { $0 is String }
    }
    
    override func prepare(withActivityItems activityItems: [Any]) {
        summaryText = activityItems.first { $0 is String } as? String
    }
    
    override func perform() {
        if let text = summaryText {
            UIPasteboard.general.string = text
        }
        activityDidFinish(true)
    }
}

final class EmailReportActivity: UIActivity {
    static let typeId = "com.systemsinspector.email-report"
    
    private var urlToAttach: URL?
    private weak var presenter: UIViewController?
    
    init(presenter: UIViewController) {
        self.presenter = presenter
        super.init()
    }
    
    override var activityType: UIActivity.ActivityType? {
        UIActivity.ActivityType(rawValue: Self.typeId)
    }
    
    override var activityTitle: String? { "Email report" }
    override var activityImage: UIImage? { UIImage(systemName: "envelope") }
    
    override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
        MFMailComposeViewController.canSendMail() &&
        activityItems.contains { item in
            guard let url = item as? URL else { return false }
            let ext = url.pathExtension.lowercased()
            return ext == "csv" || ext == "pdf"
        }
    }
    
    override func prepare(withActivityItems activityItems: [Any]) {
        urlToAttach = activityItems.first { item in
            guard let url = item as? URL else { return false }
            let ext = url.pathExtension.lowercased()
            return ext == "csv" || ext == "pdf"
        } as? URL
    }
    
    override func perform() {
        guard let url = urlToAttach, let vc = presenter else {
            activityDidFinish(false)
            return
        }
        let mail = MFMailComposeViewController()
        mail.mailComposeDelegate = self
        mail.setSubject("Systems Inspector Report")
        mail.setMessageBody("Please find the attached report.", isHTML: false)
        if let data = try? Data(contentsOf: url) {
            let mime = url.pathExtension.lowercased() == "pdf" ? "application/pdf" : "text/csv"
            mail.addAttachmentData(data, mimeType: mime, fileName: url.lastPathComponent)
        }
        vc.present(mail, animated: true) { [weak self] in
            self?.activityDidFinish(true)
        }
    }
}

extension EmailReportActivity: MFMailComposeViewControllerDelegate {
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true)
    }
}
