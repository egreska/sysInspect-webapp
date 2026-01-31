//
//  AccountCreationViewController.swift
//  Systems Inspector
//
//  Created by Eric Greska on 5/23/25.
//

import UIKit
import CryptoKit
import CoreData

class AccountCreationViewController: UIViewController {

    // MARK: - UI Components
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    private let emailTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "Email"
        textField.borderStyle = .roundedRect
        textField.keyboardType = .emailAddress
        textField.autocapitalizationType = .none
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()

    private let passwordTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "Password"
        textField.borderStyle = .roundedRect
        textField.isSecureTextEntry = true
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()

    private let confirmPasswordTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "Confirm Password"
        textField.borderStyle = .roundedRect
        textField.isSecureTextEntry = true
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()
    
    private let securityQuestionLabel: UILabel = {
        let label = UILabel()
        label.text = "Security Question (for password recovery):"
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let securityQuestionButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Select a Security Question", for: .normal)
        
        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.plain()
            config.title = "Select a Security Question"
            config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12)
            config.background.backgroundColor = UIColor.systemGray6
            config.baseForegroundColor = .systemBlue
            button.configuration = config
        } else {
            button.backgroundColor = UIColor.systemGray6
            button.setTitleColor(.systemBlue, for: .normal)
            button.contentHorizontalAlignment = .left
            button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
        }
        
        button.layer.cornerRadius = 8
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.systemGray4.cgColor
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let securityAnswerTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "Your Answer (for password recovery)"
        textField.borderStyle = .roundedRect
        textField.autocapitalizationType = .none
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()

    private let createAccountButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Create Account", for: .normal)
        button.backgroundColor = UIColor(red: 0.0, green: 0.4, blue: 0.8, alpha: 1.0)
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    // Activity Indicator
    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.hidesWhenStopped = true
        return indicator
    }()
    
    // Overlay view to block interaction during account creation
    private let overlayView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()

    // MARK: - Properties
    private var activeTextField: UITextField?
    private var selectedSecurityQuestion: String?

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
        title = "Create Account"

        // Setup scroll view
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        let stackView = UIStackView(arrangedSubviews: [
            emailTextField,
            passwordTextField,
            confirmPasswordTextField,
            securityQuestionLabel,
            securityQuestionButton,
            securityAnswerTextField,
            createAccountButton
        ])
        stackView.axis = .vertical
        stackView.spacing = 20
        stackView.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(stackView)
        view.addSubview(overlayView)
        overlayView.addSubview(activityIndicator)

        NSLayoutConstraint.activate([
            // Scroll view constraints
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Content view constraints
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // Stack view constraints
            stackView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 40),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -40),
            stackView.topAnchor.constraint(greaterThanOrEqualTo: contentView.topAnchor, constant: 40),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -40),

            // Button height constraints
            emailTextField.heightAnchor.constraint(equalToConstant: 44),
            passwordTextField.heightAnchor.constraint(equalToConstant: 44),
            confirmPasswordTextField.heightAnchor.constraint(equalToConstant: 44),
            securityQuestionButton.heightAnchor.constraint(equalToConstant: 44),
            securityAnswerTextField.heightAnchor.constraint(equalToConstant: 44),
            createAccountButton.heightAnchor.constraint(equalToConstant: 50),
            
            // Overlay constraints
            overlayView.topAnchor.constraint(equalTo: view.topAnchor),
            overlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            overlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            // Activity indicator constraints
            activityIndicator.centerXAnchor.constraint(equalTo: overlayView.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: overlayView.centerYAnchor)
        ])
    }

    // MARK: - Keyboard Handling
    private func setupKeyboardHandling() {
        // Add tap gesture to dismiss keyboard
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)
        
        // Set up text field delegates
        emailTextField.delegate = self
        passwordTextField.delegate = self
        confirmPasswordTextField.delegate = self
        
        // Register for keyboard notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }

    @objc private func keyboardWillShow(notification: NSNotification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue,
              let animationDuration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval else {
            return
        }
        
        let keyboardHeight = keyboardFrame.cgRectValue.height
        
        // Adjust scroll view content insets
        let contentInsets = UIEdgeInsets(top: 0, left: 0, bottom: keyboardHeight + 20, right: 0)
        scrollView.contentInset = contentInsets
        scrollView.scrollIndicatorInsets = contentInsets
        
        // Scroll to active field if needed
        UIView.animate(withDuration: animationDuration) {
            if let activeField = self.activeTextField {
                self.scrollToField(activeField)
            }
        }
    }

    @objc private func keyboardWillHide(notification: NSNotification) {
        guard let animationDuration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval else {
            return
        }
        
        UIView.animate(withDuration: animationDuration) {
            self.scrollView.contentInset = .zero
            self.scrollView.scrollIndicatorInsets = .zero
        }
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    private func scrollToField(_ field: UIView) {
        // Convert field frame to scroll view coordinates
        let fieldFrame = field.convert(field.bounds, to: scrollView)
        
        // Calculate the area that should be visible (field + some padding)
        let targetRect = CGRect(
            x: fieldFrame.origin.x,
            y: fieldFrame.origin.y - 20, // Add some padding above
            width: fieldFrame.width,
            height: fieldFrame.height + 40 // Add padding below
        )
        
        // Scroll to make the field visible
        scrollView.scrollRectToVisible(targetRect, animated: true)
    }

    private func setupActions() {
        createAccountButton.addTarget(self, action: #selector(createAccountTapped), for: .touchUpInside)
        securityQuestionButton.addTarget(self, action: #selector(selectSecurityQuestionTapped), for: .touchUpInside)
    }
    
    @objc private func selectSecurityQuestionTapped() {
        let alert = UIAlertController(
            title: "Select Security Question",
            message: "Choose a question you can answer to recover your password",
            preferredStyle: .actionSheet
        )
        
        for question in PasswordRecoveryManager.availableQuestions {
            alert.addAction(UIAlertAction(title: question, style: .default) { [weak self] _ in
                self?.selectedSecurityQuestion = question
                self?.securityQuestionButton.setTitle(question, for: .normal)
                self?.securityQuestionButton.setTitleColor(.label, for: .normal)
            })
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // For iPad
        if let popoverController = alert.popoverPresentationController {
            popoverController.sourceView = securityQuestionButton
            popoverController.sourceRect = securityQuestionButton.bounds
        }
        
        present(alert, animated: true)
    }

    // MARK: - Actions
    @objc private func createAccountTapped() {
        guard let email = emailTextField.text, !email.isEmpty,
              let password = passwordTextField.text, !password.isEmpty,
              let confirmPassword = confirmPasswordTextField.text, !confirmPassword.isEmpty else {
            showAlert(title: "Error", message: "Please fill in all fields.")
            return
        }

        // Validate email format
        if !isValidEmail(email) {
            showAlert(title: "Error", message: "Please enter a valid email address.")
            return
        }

        // Validate password strength - Use PasswordRecoveryManager for consistency
        let validation = PasswordRecoveryManager.shared.validatePasswordStrength(password)
        if !validation.isValid {
            showAlert(title: "Weak Password", message: validation.message)
            return
        }

        if password != confirmPassword {
            showAlert(title: "Error", message: "Passwords do not match.")
            return
        }
        
        // Validate security question
        guard let securityQuestion = selectedSecurityQuestion else {
            showAlert(title: "Error", message: "Please select a security question for password recovery.")
            return
        }
        
        guard let securityAnswer = securityAnswerTextField.text, !securityAnswer.isEmpty else {
            showAlert(title: "Error", message: "Please provide an answer to your security question.")
            return
        }
        
        if securityAnswer.count < 3 {
            showAlert(title: "Error", message: "Security answer must be at least 3 characters long.")
            return
        }

        // Check if user already exists locally
        if UserManager.shared.userExists(email: email) {
            showAlert(title: "Error", message: "An account with this email already exists locally. Please try logging in or using a different email.")
            return
        }
        
        showActivityIndicator(true)
        print("🔄 Starting account creation for: \(email)")

        Task {
            let success = await UserManager.shared.createUser(email: email, password: password)
            
            if success {
                // Set security question
                let securitySuccess = PasswordRecoveryManager.shared.setSecurityQuestion(
                    for: email,
                    question: securityQuestion,
                    answer: securityAnswer
                )
                
                await MainActor.run {
                    self.showActivityIndicator(false)
                    if securitySuccess {
                        print("✅ Account creation and security question set successfully")
                        self.showAlert(title: "Account Created", message: "Your account has been successfully created with password recovery!") {
                            self.navigationController?.popViewController(animated: true)
                        }
                    } else {
                        print("⚠️ Account created but security question failed")
                        self.showAlert(title: "Account Created", message: "Your account was created, but password recovery setup failed. You can still login.") {
                            self.navigationController?.popViewController(animated: true)
                        }
                    }
                }
            } else {
                await MainActor.run {
                    self.showActivityIndicator(false)
                    print("❌ Account creation failed")
                    self.showAlert(title: "Account Creation Failed", message: "Failed to create account. Please check your internet connection and try again. If the problem persists, this email might already be registered.")
                }
            }
        }
    }

    // MARK: - Validation Helpers
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }

    private func isValidPassword(_ password: String) -> Bool {
        return password.count >= 6
    }

    private func showAlert(title: String, message: String, completion: (() -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            completion?()
        })
        present(alert, animated: true)
    }
    
    private func showActivityIndicator(_ show: Bool) {
        overlayView.isHidden = !show
        if show {
            activityIndicator.startAnimating()
        } else {
            activityIndicator.stopAnimating()
        }
    }
    
    // MARK: - Cleanup
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - UITextFieldDelegate
extension AccountCreationViewController: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        activeTextField = textField
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        activeTextField = nil
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == emailTextField {
            passwordTextField.becomeFirstResponder()
        } else if textField == passwordTextField {
            confirmPasswordTextField.becomeFirstResponder()
        } else if textField == confirmPasswordTextField {
            textField.resignFirstResponder()
            createAccountTapped()
        }
        return true
    }
}
