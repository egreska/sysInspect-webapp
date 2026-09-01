//
//  ToastView.swift
//  Systems Inspector
//
//  Brief banner/toast for success or undo feedback.
//

import UIKit

/// Shows a short message (and optional action) at the top or bottom of a view.
final class ToastView: UIView {
    private let messageLabel = UILabel()
    private let actionButton = UIButton(type: .system)
    private var actionHandler: (() -> Void)?
    
    static func show(on viewController: UIViewController, message: String, actionTitle: String? = nil, action: (() -> Void)? = nil, duration: TimeInterval = 2.5) {
        let toast = ToastView()
        toast.translatesAutoresizingMaskIntoConstraints = false
        toast.messageLabel.text = message
        toast.messageLabel.font = AppTheme.font(.subheadline)
        toast.messageLabel.textColor = AppTheme.primaryContrast
        toast.messageLabel.numberOfLines = 2
        toast.backgroundColor = UIColor(white: 0.15, alpha: 0.98)
        toast.layer.cornerRadius = 10
        toast.actionHandler = action
        
        if let title = actionTitle, action != nil {
            toast.actionButton.setTitle(title, for: .normal)
            toast.actionButton.setTitleColor(.systemYellow, for: .normal)
            toast.actionButton.titleLabel?.font = AppTheme.fontMedium(.subheadline)
            toast.actionButton.addTarget(toast, action: #selector(toast.actionTapped), for: .touchUpInside)
        } else {
            toast.actionButton.isHidden = true
        }
        
        toast.messageLabel.translatesAutoresizingMaskIntoConstraints = false
        toast.actionButton.translatesAutoresizingMaskIntoConstraints = false
        toast.addSubview(toast.messageLabel)
        toast.addSubview(toast.actionButton)
        
        NSLayoutConstraint.activate([
            toast.messageLabel.leadingAnchor.constraint(equalTo: toast.leadingAnchor, constant: 16),
            toast.messageLabel.topAnchor.constraint(equalTo: toast.topAnchor, constant: 12),
            toast.messageLabel.bottomAnchor.constraint(equalTo: toast.bottomAnchor, constant: -12),
            toast.actionButton.leadingAnchor.constraint(equalTo: toast.messageLabel.trailingAnchor, constant: 12),
            toast.actionButton.trailingAnchor.constraint(equalTo: toast.trailingAnchor, constant: -16),
            toast.actionButton.centerYAnchor.constraint(equalTo: toast.messageLabel.centerYAnchor)
        ])
        
        guard let view = viewController.view else { return }
        view.addSubview(toast)
        NSLayoutConstraint.activate([
            toast.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            toast.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            toast.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24)
        ])
        toast.alpha = 0
        UIView.animate(withDuration: 0.25) { toast.alpha = 1 }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            UIView.animate(withDuration: 0.25, animations: { toast.alpha = 0 }) { _ in
                toast.removeFromSuperview()
            }
        }
    }
    
    @objc private func actionTapped() {
        actionHandler?()
        UIView.animate(withDuration: 0.2, animations: { self.alpha = 0 }) { _ in
            self.removeFromSuperview()
        }
    }
}
