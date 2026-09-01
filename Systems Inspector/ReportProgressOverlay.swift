//
//  ReportProgressOverlay.swift
//  Systems Inspector
//
//  Full-screen overlay with spinner and message during report generation.
//

import UIKit

final class ReportProgressOverlay: UIView {
    private let blurView: UIVisualEffectView = {
        let effect = UIBlurEffect(style: .systemChromeMaterialDark)
        let v = UIVisualEffectView(effect: effect)
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()
    
    private let container: UIView = {
        let v = UIView()
        v.backgroundColor = AppTheme.surface.withAlphaComponent(0.9)
        v.layer.cornerRadius = 12
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()
    
    private let activityIndicator: UIActivityIndicatorView = {
        let i = UIActivityIndicatorView(style: .large)
        i.translatesAutoresizingMaskIntoConstraints = false
        i.color = AppTheme.primary
        return i
    }()
    
    private let messageLabel: UILabel = {
        let l = UILabel()
        l.font = AppTheme.font(.headline)
        l.textColor = AppTheme.textPrimary
        l.textAlignment = .center
        l.numberOfLines = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        addSubview(blurView)
        addSubview(container)
        container.addSubview(activityIndicator)
        container.addSubview(messageLabel)
        
        NSLayoutConstraint.activate([
            blurView.topAnchor.constraint(equalTo: topAnchor),
            blurView.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: bottomAnchor),
            container.centerXAnchor.constraint(equalTo: centerXAnchor),
            container.centerYAnchor.constraint(equalTo: centerYAnchor),
            container.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 32),
            container.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -32),
            activityIndicator.topAnchor.constraint(equalTo: container.topAnchor, constant: 24),
            activityIndicator.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            messageLabel.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 16),
            messageLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 24),
            messageLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -24),
            messageLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -24)
        ])
    }
    
    func setMessage(_ text: String) {
        messageLabel.text = text
    }
    
    func show(in viewController: UIViewController, message: String) {
        setMessage(message)
        guard let view = viewController.view else { return }
        frame = view.bounds
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(self)
        activityIndicator.startAnimating()
    }
    
    func hide() {
        activityIndicator.stopAnimating()
        removeFromSuperview()
    }
}
