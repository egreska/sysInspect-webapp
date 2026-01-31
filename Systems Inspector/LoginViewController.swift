//
//  LoginViewController.swift
//  Systems Inspector
//
//  Created by Eric Greska on 5/23/25.
//

import UIKit
import LocalAuthentication

class LoginViewController: UIViewController {

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
    
    private let forgotPasswordButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Forgot Password?", for: .normal)
        button.setTitleColor(UIColor(red: 0.0, green: 0.4, blue: 0.8, alpha: 1.0), for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14)
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
    
    // Overlay view to block interaction during login
    private let overlayView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()

    // MARK: - Properties
    private var activeTextField: UITextField?
    private var isAuthenticating = false

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        print("🔵 LoginViewController: viewDidLoad called")
        setupUI()
        setupActions()
        setupKeyboardHandling()
        checkBiometricAvailability()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Log screen view
        AnalyticsManager.shared.logScreenView(
            screenName: "Login",
            screenClass: String(describing: type(of: self))
        )
        
        // Check if user is already logged in
        if UserManager.shared.isUserLoggedIn() {
            Task {
                await performSuccessfulLogin()
            }
        }
    }

    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "Log In"

        // Setup scroll view
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        let stackView = UIStackView(arrangedSubviews: [
            emailTextField,
            passwordTextField,
            loginButton,
            facialRecognitionButton,
            forgotPasswordButton,
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
            loginButton.heightAnchor.constraint(equalToConstant: 50),
            facialRecognitionButton.heightAnchor.constraint(equalToConstant: 50),
            
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
        loginButton.addTarget(self, action: #selector(loginTapped), for: .touchUpInside)
        facialRecognitionButton.addTarget(self, action: #selector(facialRecognitionLoginTapped), for: .touchUpInside)
        forgotPasswordButton.addTarget(self, action: #selector(forgotPasswordTapped), for: .touchUpInside)
        createAccountButton.addTarget(self, action: #selector(createAccountTapped), for: .touchUpInside)
    }
    
    private func checkBiometricAvailability() {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            switch context.biometryType {
            case .faceID:
                facialRecognitionButton.setTitle("Log In with Face ID", for: .normal)
            case .touchID:
                facialRecognitionButton.setTitle("Log In with Touch ID", for: .normal)
            case .opticID:
                if #available(iOS 17.0, *) {
                    facialRecognitionButton.setTitle("Log In with Optic ID", for: .normal)
                } else {
                    facialRecognitionButton.setTitle("Biometric Login", for: .normal)
                }
            case .none:
                facialRecognitionButton.setTitle("Biometric Login", for: .normal)
            @unknown default:
                facialRecognitionButton.setTitle("Biometric Login", for: .normal)
            }
            facialRecognitionButton.isEnabled = true
        } else {
            facialRecognitionButton.setTitle("Biometric Login Unavailable", for: .normal)
            facialRecognitionButton.isEnabled = false
            facialRecognitionButton.backgroundColor = .systemGray2
        }
    }

    // MARK: - Actions
    @objc private func loginTapped() {
        print("🔵 LoginViewController: Login button tapped")
        
        // Prevent multiple simultaneous login attempts
        guard !isAuthenticating else {
            print("🔵 LoginViewController: Authentication already in progress")
            return
        }
        
        guard let email = emailTextField.text, !email.isEmpty,
              let password = passwordTextField.text, !password.isEmpty else {
            showAlert(title: "Error", message: "Please enter both email and password.")
            return
        }
        
        // Check if account is locked
        if AccountLockoutManager.shared.isAccountLocked(email: email) {
            let remainingTime = AccountLockoutManager.shared.getRemainingLockoutTime(email: email)
            let formattedTime = AccountLockoutManager.shared.formatRemainingTime(remainingTime)
            showAlert(
                title: "Account Locked",
                message: "Too many failed login attempts. Please try again in \(formattedTime)."
            )
            return
        }

        isAuthenticating = true
        showActivityIndicator(true)
        
        Task {
            let authResult = await UserManager.shared.authenticateUser(email: email, password: password)
            
            await MainActor.run {
                self.isAuthenticating = false
                
                if authResult {
                    Task {
                        await self.performSuccessfulLogin()
                    }
                } else {
                    self.showActivityIndicator(false)
                    
                    // Show remaining attempts
                    let remainingAttempts = AccountLockoutManager.shared.getRemainingAttempts(email: email)
                    if remainingAttempts > 0 {
                        self.showAlert(
                            title: "Login Failed",
                            message: "Invalid email or password.\n\(remainingAttempts) attempt\(remainingAttempts == 1 ? "" : "s") remaining before account lockout."
                        )
                    } else {
                        self.showAlert(
                            title: "Account Locked",
                            message: "Too many failed login attempts. Your account has been locked for 15 minutes for security."
                        )
                    }
                }
            }
        }
    }

    @objc private func facialRecognitionLoginTapped() {
        print("🔵 LoginViewController: Face ID button tapped")
        
        // Prevent multiple simultaneous login attempts
        guard !isAuthenticating else {
            print("🔵 LoginViewController: Authentication already in progress")
            return
        }
        
        guard let currentUser = UserManager.shared.getCurrentUser(), let userEmail = currentUser.email else {
            showAlert(title: "No Account", message: "Please log in with email and password first to enable biometric authentication.")
            return
        }
        
        isAuthenticating = true
        
        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let reason = "Authenticate to log in to Rack Inspector"

            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { [weak self] success, authenticationError in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    
                    self.isAuthenticating = false
                    
                    if success {
                        print("🔵 LoginViewController: Biometric authentication successful")
                        
                        // Set user as logged in
                        UserDefaults.standard.set(userEmail, forKey: "currentUserEmail")
                        UserDefaults.standard.set(currentUser.id?.uuidString, forKey: "currentUserID")
                        UserDefaults.standard.set(true, forKey: "isLoggedIn")
                        CoreDataManager.shared.currentUserID = currentUser.id
                        
                        Task {
                            await self.performSuccessfulLogin()
                        }
                        
                    } else {
                        let errorMessage = authenticationError?.localizedDescription ?? "Failed to authenticate with biometrics."
                        print("🔴 LoginViewController: Biometric authentication failed: \(errorMessage)")
                        self.showAlert(title: "Authentication Failed", message: errorMessage)
                    }
                }
            }
        } else {
            isAuthenticating = false
            let errorMessage = error?.localizedDescription ?? "Your device does not support biometric authentication or it is not configured."
            showAlert(title: "Biometric Authentication Not Available", message: errorMessage)
        }
    }

    @objc private func createAccountTapped() {
        print("🔵 LoginViewController: Create account button tapped")
        
        let accountCreationVC = AccountCreationViewController()
        navigationController?.pushViewController(accountCreationVC, animated: true)
    }
    
    @objc private func forgotPasswordTapped() {
        print("🔵 LoginViewController: Forgot password button tapped")
        
        let forgotPasswordVC = ForgotPasswordViewController()
        let navController = UINavigationController(rootViewController: forgotPasswordVC)
        present(navController, animated: true)
    }

    private func performSuccessfulLogin() async {
        print("🔵 LoginViewController: Performing successful login")
        
        await MainActor.run {
            self.showActivityIndicator(true)
        }

        // Small delay to ensure CloudKit is ready
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        await MainActor.run {
            print("🔵 LoginViewController: Transitioning to MainTabBarController")
            
            if let sceneDelegate = UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate,
               let window = sceneDelegate.window {
                let mainTabBarController = MainTabBarController()
                window.rootViewController = mainTabBarController
                UIView.transition(with: window, duration: 0.5, options: .transitionCrossDissolve, animations: nil, completion: nil)
                print("🔵 LoginViewController: Transitioned to MainTabBarController")
            }
            self.showActivityIndicator(false)
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
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
extension LoginViewController: UITextFieldDelegate {
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
            textField.resignFirstResponder()
            loginTapped()
        }
        return true
    }
}
