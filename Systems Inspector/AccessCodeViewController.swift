//
//  AccessCodeViewController.swift
//  Systems Inspector
//

import UIKit

final class AccessCodeViewController: UIViewController {
    private let messageLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = .preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = AppTheme.textPrimary
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let codeField: UITextField = {
        let field = UITextField()
        field.placeholder = "Access Code"
        field.borderStyle = .roundedRect
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.accessibilityLabel = "Access Code"
        field.translatesAutoresizingMaskIntoConstraints = false
        return field
    }()

    private let actionButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = AppTheme.primary
        button.setTitleColor(AppTheme.primaryContrast, for: .normal)
        button.layer.cornerRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()

    private var route: AccessRoute

    init(route: AccessRoute) {
        self.route = route
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        self.route = .enterCode(nil)
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppTheme.background
        title = "Access Code"

        let stack = UIStackView(arrangedSubviews: [messageLabel, codeField, actionButton])
        stack.axis = .vertical
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        view.addSubview(activityIndicator)
        actionButton.addTarget(self, action: #selector(actionTapped), for: .touchUpInside)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 40),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -40),
            stack.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
            codeField.heightAnchor.constraint(equalToConstant: 44),
            actionButton.heightAnchor.constraint(equalToConstant: 50),
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.topAnchor.constraint(equalTo: stack.bottomAnchor, constant: 24)
        ])
        apply(route)
    }

    func apply(_ route: AccessRoute) {
        self.route = route
        guard isViewLoaded else { return }
        activityIndicator.stopAnimating()
        actionButton.isEnabled = true

        switch route {
        case .signInToICloud:
            messageLabel.text = "Sign in to iCloud in Settings. Pallet Rack Safety uses that Apple ID as the inspector."
            codeField.isHidden = true
            actionButton.setTitle("Check Again", for: .normal)
            actionButton.accessibilityLabel = "Check Again"
        case .needNetwork:
            messageLabel.text = "The Access Code could not be checked. Connect to the network and try again."
            codeField.isHidden = false
            actionButton.setTitle("Try Again", for: .normal)
            actionButton.accessibilityLabel = "Try Again"
        case .enterCode(let notice):
            messageLabel.text = noticeText(notice) ?? "Enter the Access Code issued for this Apple ID."
            codeField.isHidden = false
            actionButton.setTitle("Continue", for: .normal)
            actionButton.accessibilityLabel = "Continue"
        case .waitingForSession:
            messageLabel.text = "This Apple ID already has an account. Waiting for it to sync from iCloud."
            codeField.isHidden = true
            actionButton.setTitle("Check Again", for: .normal)
            actionButton.accessibilityLabel = "Check Again"
        case .login, .mainApp:
            break
        }
    }

    @objc private func actionTapped() {
        guard let sceneDelegate = UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate,
              let window = sceneDelegate.window else { return }
        actionButton.isEnabled = false
        activityIndicator.startAnimating()
        Task {
            switch route {
            case .enterCode, .needNetwork:
                await AccessCodeCoordinator.shared.submit(code: codeField.text ?? "", in: window)
            default:
                await AccessCodeCoordinator.shared.recheck(in: window)
            }
            actionButton.isEnabled = true
            activityIndicator.stopAnimating()
        }
    }

    private func noticeText(_ notice: AccessCodeNotice?) -> String? {
        switch notice {
        case .notIssued:
            return "That is not an issued Access Code."
        case .otherAppleID:
            return "That Access Code belongs to another Apple ID."
        case .retired:
            return "That Access Code is retired. Enter a newly issued code."
        case nil:
            return nil
        }
    }
}
