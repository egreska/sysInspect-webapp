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

    private let createAccountButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Create Account", for: .normal)
        button.backgroundColor = UIColor(red: 0.0, green: 0.4, blue: 0.8, alpha: 1.0)
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupActions()
    }

    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "Create Account"

        let stackView = UIStackView(arrangedSubviews: [emailTextField, passwordTextField, confirmPasswordTextField, createAccountButton])
        stackView.axis = .vertical
        stackView.spacing = 20
        stackView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),

            emailTextField.heightAnchor.constraint(equalToConstant: 44),
            passwordTextField.heightAnchor.constraint(equalToConstant: 44),
            confirmPasswordTextField.heightAnchor.constraint(equalToConstant: 44),
            createAccountButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }

    private func setupActions() {
        createAccountButton.addTarget(self, action: #selector(createAccountTapped), for: .touchUpInside)
    }

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

        // Validate password strength
        if !isValidPassword(password) {
            showAlert(title: "Error", message: "Password must be at least 6 characters long.")
            return
        }

        if password != confirmPassword {
            showAlert(title: "Error", message: "Passwords do not match.")
            return
        }

        // Check if user already exists
        if UserManager.shared.userExists(email: email) {
            showAlert(title: "Error", message: "An account with this email already exists.")
            return
        }

        // Create the user account
        if UserManager.shared.createUser(email: email, password: password) {
            showAlert(title: "Account Created", message: "Your account has been successfully created!") { [weak self] in
                self?.navigationController?.popViewController(animated: true)
            }
        } else {
            showAlert(title: "Error", message: "Failed to create account. Please try again.")
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
}
