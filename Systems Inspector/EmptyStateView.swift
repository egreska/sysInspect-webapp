//
//  EmptyStateView.swift
//  Systems Inspector
//
//  Reusable empty state with optional SF Symbol, title, message, and CTA.
//

import UIKit

final class EmptyStateView: UIView {

    // MARK: - UI

    private let symbolStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = AppTheme.fontBold(.title3)
        label.textColor = AppTheme.textPrimary
        label.textAlignment = .center
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let messageLabel: UILabel = {
        let label = UILabel()
        label.font = AppTheme.font(.body)
        label.textColor = AppTheme.textSecondary
        label.textAlignment = .center
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let actionButton: UIButton = {
        let button = UIButton(type: .system)
        button.titleLabel?.font = AppTheme.fontMedium(.headline)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.backgroundColor = AppTheme.primary
        button.setTitleColor(AppTheme.primaryContrast, for: .normal)
        button.layer.cornerRadius = 10
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isHidden = true
        return button
    }()

    private var actionHandler: (() -> Void)?

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        addSubview(symbolStack)
        addSubview(titleLabel)
        addSubview(messageLabel)
        addSubview(actionButton)
        actionButton.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
        NSLayoutConstraint.activate([
            symbolStack.topAnchor.constraint(equalTo: topAnchor),
            symbolStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            symbolStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            titleLabel.topAnchor.constraint(equalTo: symbolStack.bottomAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            messageLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            messageLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            actionButton.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 24),
            actionButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            actionButton.heightAnchor.constraint(equalToConstant: 48),
            actionButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 180),
            actionButton.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    @objc private func buttonTapped() {
        actionHandler?()
    }

    // MARK: - Configuration

    /// Configure with SF Symbol name(s), title, message, and optional CTA.
    /// For multiple symbols, pass names in order (e.g. ["person.3", "plus.circle"]).
    func configure(
        symbolNames: [String] = [],
        symbolPointSize: CGFloat = 56,
        symbolColor: UIColor? = nil,
        title: String,
        message: String,
        buttonTitle: String? = nil,
        buttonAction: (() -> Void)? = nil
    ) {
        titleLabel.text = title
        messageLabel.text = message

        symbolStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let color = symbolColor ?? AppTheme.textTertiary
        let config = UIImage.SymbolConfiguration(pointSize: symbolPointSize, weight: .light)
        if symbolNames.isEmpty {
            // Single generic icon
            let imageView = UIImageView(image: UIImage(systemName: "tray", withConfiguration: config))
            imageView.tintColor = color
            imageView.contentMode = .scaleAspectFit
            symbolStack.addArrangedSubview(imageView)
        } else {
            for name in symbolNames {
                guard let image = UIImage(systemName: name, withConfiguration: config) else { continue }
                let imageView = UIImageView(image: image)
                imageView.tintColor = color
                imageView.contentMode = .scaleAspectFit
                symbolStack.addArrangedSubview(imageView)
            }
        }

        if let title = buttonTitle, let action = buttonAction {
            actionButton.setTitle(title, for: .normal)
            actionButton.isHidden = false
            actionHandler = action
        } else {
            actionButton.isHidden = true
            actionHandler = nil
        }
    }
}
