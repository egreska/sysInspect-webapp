//
//  LoginViewController.swift
//  Systems Inspector
//
//  Created by Eric Greska on 5/23/25.
//

import UIKit
import LocalAuthentication

class LoginViewController: UIViewController {

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

    private let loginButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Log In", for: .normal)
        button.backgroundColor = UIColor(red: 0.0, green: 0.4, blue: 0.8, alpha: 1.0)
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let facialRecognitionButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Log In with Face ID", for: .normal)
        button.backgroundColor = .systemGray
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let createAccountButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Create New Account", for: .normal)
        button.setTitleColor(UIColor(red: 0.0, green: 0.4, blue: 0.8, alpha: 1.0), for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        print("🔵 LoginViewController: viewDidLoad called")
        setupUI()
        setupActions()
        checkBiometricAvailability()
    }

    override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            
            // Check if user is already logged in
            if UserManager.shared.isUserLoggedIn() {
                performSuccessfulLogin()
            }
        }

        private func setupUI() {
            view.backgroundColor = .systemBackground
            title = "Log In"

            let stackView = UIStackView(arrangedSubviews: [emailTextField, passwordTextField, loginButton, facialRecognitionButton, createAccountButton])
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
                loginButton.heightAnchor.constraint(equalToConstant: 50),
                facialRecognitionButton.heightAnchor.constraint(equalToConstant: 50)
            ])
        }

        private func setupActions() {
            loginButton.addTarget(self, action: #selector(loginTapped), for: .touchUpInside)
            facialRecognitionButton.addTarget(self, action: #selector(facialRecognitionLoginTapped), for: .touchUpInside)
            createAccountButton.addTarget(self, action: #selector(createAccountTapped), for: .touchUpInside)
        }
        
        private func checkBiometricAvailability() {
            let context = LAContext()
            var error: NSError?
            
            if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
                // Check what type of biometric authentication is available
                switch context.biometryType {
                case .faceID:
                    facialRecognitionButton.setTitle("Log In with Face ID", for: .normal)
                case .touchID:
                    facialRecognitionButton.setTitle("Log In with Touch ID", for: .normal)
                case .none:
                    facialRecognitionButton.setTitle("Biometric Login", for: .normal)
                @unknown default:
                    facialRecognitionButton.setTitle("Biometric Login", for: .normal)
                }
                facialRecognitionButton.isEnabled = true
            } else {
                // Biometric authentication not available
                facialRecognitionButton.setTitle("Biometric Login Unavailable", for: .normal)
                facialRecognitionButton.isEnabled = false
                facialRecognitionButton.backgroundColor = .systemGray2
            }
        }

        @objc private func loginTapped() {
            print("🔵 LoginViewController: Login button tapped")
            
            guard let email = emailTextField.text, !email.isEmpty,
                  let password = passwordTextField.text, !password.isEmpty else {
                showAlert(title: "Error", message: "Please enter both email and password.")
                return
            }

            // UPDATED: Use UserManager for authentication
            if UserManager.shared.authenticateUser(email: email, password: password) {
                performSuccessfulLogin()
            } else {
                showAlert(title: "Login Failed", message: "Invalid email or password.")
            }
        }

        @objc private func facialRecognitionLoginTapped() {
            print("🔵 LoginViewController: Face ID button tapped")
            
            // Check if there's a current user for biometric login
            guard UserManager.shared.getCurrentUser() != nil else {
                showAlert(title: "No Account", message: "Please log in with email and password first to enable biometric authentication.")
                return
            }
            
            let context = LAContext()
            var error: NSError?

            // Check if biometric authentication is available
            if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
                let reason = "Authenticate to log in to Systems Inspector"

                context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { [weak self] success, authenticationError in
                    DispatchQueue.main.async {
                        if success {
                            print("🔵 LoginViewController: Biometric authentication successful")
                            self?.performSuccessfulLogin()
                        } else {
                            // Handle authentication failure
                            let errorMessage = authenticationError?.localizedDescription ?? "Failed to authenticate with biometrics."
                            print("🔴 LoginViewController: Biometric authentication failed: \(errorMessage)")
                            self?.showAlert(title: "Authentication Failed", message: errorMessage)
                        }
                    }
                }
            } else {
                // Biometric authentication not available
                let errorMessage = error?.localizedDescription ?? "Your device does not support biometric authentication or it is not configured."
                showAlert(title: "Biometric Authentication Not Available", message: errorMessage)
            }
        }

        @objc private func createAccountTapped() {
            print("🔵 LoginViewController: Create account button tapped")
            
            let accountCreationVC = AccountCreationViewController()
            navigationController?.pushViewController(accountCreationVC, animated: true)
        }

        private func performSuccessfulLogin() {
            print("🔵 LoginViewController: Performing successful login, transitioning to MainTabBarController")
            
            // Dismiss the login screen and present the main tab bar controller
            if let sceneDelegate = UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate,
               let window = sceneDelegate.window {
                let mainTabBarController = MainTabBarController()
                window.rootViewController = mainTabBarController
                UIView.transition(with: window, duration: 0.5, options: .transitionCrossDissolve, animations: nil, completion: nil)
                print("🔵 LoginViewController: Transitioned to MainTabBarController")
            }
        }

        private func showAlert(title: String, message: String) {
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }
