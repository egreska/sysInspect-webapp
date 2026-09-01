//
//  ForgotPasswordViewController.swift
//  Systems Inspector
//
//  Handles password recovery flow
//  Created on 1/29/26.
//

import UIKit

class ForgotPasswordViewController: UIViewController {
    
    // MARK: - UI Components
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Reset Password"
        label.font = .preferredFont(forTextStyle: .title1)
        label.adjustsFontForContentSizeCategory = true
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let instructionLabel: UILabel = {
        let label = UILabel()
        label.text = "Enter your email and answer your security question to reset your password."
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.adjustsFontForContentSizeCategory = true
        label.textAlignment = .center
        label.numberOfLines = 0
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let emailTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "Email"
        textField.borderStyle = .roundedRect
        textField.keyboardType = .emailAddress
        textField.autocapitalizationType = .none
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()
    
    private let checkEmailButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Check Email", for: .normal)
        button.backgroundColor = AppTheme.primary
        button.setTitleColor(AppTheme.primaryContrast, for: .normal)
        button.layer.cornerRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    // Security question section (hidden initially)
    private let securityQuestionContainerView = UIView()
    
    private let securityQuestionLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let securityAnswerTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "Your Answer"
        textField.borderStyle = .roundedRect
        textField.autocapitalizationType = .none
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()
    
    private let newPasswordTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "New Password"
        textField.borderStyle = .roundedRect
        textField.isSecureTextEntry = true
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()
    
    private let confirmPasswordTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "Confirm New Password"
        textField.borderStyle = .roundedRect
        textField.isSecureTextEntry = true
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()
    
    private let passwordRequirementsLabel: UILabel = {
        let label = UILabel()
        label.text = "Password must be at least 8 characters with uppercase, lowercase, and numbers."
        label.font = .preferredFont(forTextStyle: .caption1)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let resetPasswordButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Reset Password", for: .normal)
        button.backgroundColor = UIColor.systemGreen
        button.setTitleColor(AppTheme.primaryContrast, for: .normal)
        button.layer.cornerRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let cancelButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Cancel", for: .normal)
        button.setTitleColor(AppTheme.secondary, for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.hidesWhenStopped = true
        return indicator
    }()
    
    // MARK: - Properties
    private var currentEmail: String?
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupActions()
        setupKeyboardHandling()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        securityQuestionContainerView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        contentView.addSubview(titleLabel)
        contentView.addSubview(instructionLabel)
        contentView.addSubview(emailTextField)
        contentView.addSubview(checkEmailButton)
        contentView.addSubview(securityQuestionContainerView)
        contentView.addSubview(cancelButton)
        view.addSubview(activityIndicator)
        
        // Security question container
        securityQuestionContainerView.addSubview(securityQuestionLabel)
        securityQuestionContainerView.addSubview(securityAnswerTextField)
        securityQuestionContainerView.addSubview(newPasswordTextField)
        securityQuestionContainerView.addSubview(confirmPasswordTextField)
        securityQuestionContainerView.addSubview(passwordRequirementsLabel)
        securityQuestionContainerView.addSubview(resetPasswordButton)
        
        // Initially hide security question section
        securityQuestionContainerView.isHidden = true
        
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
            
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 40),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 40),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -40),
            
            instructionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            instructionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 40),
            instructionLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -40),
            
            emailTextField.topAnchor.constraint(equalTo: instructionLabel.bottomAnchor, constant: 32),
            emailTextField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 40),
            emailTextField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -40),
            emailTextField.heightAnchor.constraint(equalToConstant: 44),
            
            checkEmailButton.topAnchor.constraint(equalTo: emailTextField.bottomAnchor, constant: 20),
            checkEmailButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 40),
            checkEmailButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -40),
            checkEmailButton.heightAnchor.constraint(equalToConstant: 50),
            
            // Security question container
            securityQuestionContainerView.topAnchor.constraint(equalTo: checkEmailButton.bottomAnchor, constant: 32),
            securityQuestionContainerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 40),
            securityQuestionContainerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -40),
            
            securityQuestionLabel.topAnchor.constraint(equalTo: securityQuestionContainerView.topAnchor),
            securityQuestionLabel.leadingAnchor.constraint(equalTo: securityQuestionContainerView.leadingAnchor),
            securityQuestionLabel.trailingAnchor.constraint(equalTo: securityQuestionContainerView.trailingAnchor),
            
            securityAnswerTextField.topAnchor.constraint(equalTo: securityQuestionLabel.bottomAnchor, constant: 12),
            securityAnswerTextField.leadingAnchor.constraint(equalTo: securityQuestionContainerView.leadingAnchor),
            securityAnswerTextField.trailingAnchor.constraint(equalTo: securityQuestionContainerView.trailingAnchor),
            securityAnswerTextField.heightAnchor.constraint(equalToConstant: 44),
            
            newPasswordTextField.topAnchor.constraint(equalTo: securityAnswerTextField.bottomAnchor, constant: 20),
            newPasswordTextField.leadingAnchor.constraint(equalTo: securityQuestionContainerView.leadingAnchor),
            newPasswordTextField.trailingAnchor.constraint(equalTo: securityQuestionContainerView.trailingAnchor),
            newPasswordTextField.heightAnchor.constraint(equalToConstant: 44),
            
            confirmPasswordTextField.topAnchor.constraint(equalTo: newPasswordTextField.bottomAnchor, constant: 12),
            confirmPasswordTextField.leadingAnchor.constraint(equalTo: securityQuestionContainerView.leadingAnchor),
            confirmPasswordTextField.trailingAnchor.constraint(equalTo: securityQuestionContainerView.trailingAnchor),
            confirmPasswordTextField.heightAnchor.constraint(equalToConstant: 44),
            
            passwordRequirementsLabel.topAnchor.constraint(equalTo: confirmPasswordTextField.bottomAnchor, constant: 8),
            passwordRequirementsLabel.leadingAnchor.constraint(equalTo: securityQuestionContainerView.leadingAnchor),
            passwordRequirementsLabel.trailingAnchor.constraint(equalTo: securityQuestionContainerView.trailingAnchor),
            
            resetPasswordButton.topAnchor.constraint(equalTo: passwordRequirementsLabel.bottomAnchor, constant: 24),
            resetPasswordButton.leadingAnchor.constraint(equalTo: securityQuestionContainerView.leadingAnchor),
            resetPasswordButton.trailingAnchor.constraint(equalTo: securityQuestionContainerView.trailingAnchor),
            resetPasswordButton.heightAnchor.constraint(equalToConstant: 50),
            resetPasswordButton.bottomAnchor.constraint(equalTo: securityQuestionContainerView.bottomAnchor),
            
            cancelButton.topAnchor.constraint(equalTo: securityQuestionContainerView.bottomAnchor, constant: 24),
            cancelButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            cancelButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -40),
            
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    private func setupActions() {
        checkEmailButton.addTarget(self, action: #selector(checkEmailTapped), for: .touchUpInside)
        resetPasswordButton.addTarget(self, action: #selector(resetPasswordTapped), for: .touchUpInside)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
    }
    
    private func setupKeyboardHandling() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    // MARK: - Actions
    @objc private func checkEmailTapped() {
        guard let email = emailTextField.text, !email.isEmpty else {
            showAlert(title: "Error", message: "Please enter your email address.")
            return
        }
        
        // Check if user has security question set up
        if PasswordRecoveryManager.shared.hasSecurityQuestion(for: email) {
            if let question = PasswordRecoveryManager.shared.getSecurityQuestion(for: email) {
                currentEmail = email
                securityQuestionLabel.text = question
                
                // Show security question section
                UIView.animate(withDuration: 0.3) {
                    self.securityQuestionContainerView.isHidden = false
                    self.checkEmailButton.isEnabled = false
                    self.checkEmailButton.alpha = 0.5
                    self.emailTextField.isEnabled = false
                }
            }
        } else {
            showAlert(
                title: "Security Question Not Set",
                message: "This account doesn't have a security question set up. Please contact support or create a new account."
            )
        }
    }
    
    @objc private func resetPasswordTapped() {
        guard let email = currentEmail else { return }
        
        guard let answer = securityAnswerTextField.text, !answer.isEmpty else {
            showAlert(title: "Error", message: "Please answer the security question.")
            return
        }
        
        guard let newPassword = newPasswordTextField.text, !newPassword.isEmpty else {
            showAlert(title: "Error", message: "Please enter a new password.")
            return
        }
        
        guard let confirmPassword = confirmPasswordTextField.text, !confirmPassword.isEmpty else {
            showAlert(title: "Error", message: "Please confirm your password.")
            return
        }
        
        guard newPassword == confirmPassword else {
            showAlert(title: "Error", message: "Passwords do not match.")
            return
        }
        
        // Validate password strength
        let validation = PasswordRecoveryManager.shared.validatePasswordStrength(newPassword)
        guard validation.isValid else {
            showAlert(title: "Weak Password", message: validation.message)
            return
        }
        
        activityIndicator.startAnimating()
        
        Task {
            let result = await PasswordRecoveryManager.shared.resetPassword(
                for: email,
                newPassword: newPassword,
                securityAnswer: answer
            )
            
            await MainActor.run {
                activityIndicator.stopAnimating()
                
                if result.success {
                    let alert = UIAlertController(
                        title: "Success",
                        message: result.message,
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
                        self?.dismiss(animated: true)
                    })
                    present(alert, animated: true)
                } else {
                    showAlert(title: "Error", message: result.message)
                }
            }
        }
    }
    
    @objc private func cancelTapped() {
        dismiss(animated: true)
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
