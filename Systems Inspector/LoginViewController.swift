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
        textField.font = AppTheme.font(.body)
        textField.adjustsFontForContentSizeCategory = true
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()

    private let passwordTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "Password"
        textField.borderStyle = .roundedRect
        textField.isSecureTextEntry = true
        textField.font = AppTheme.font(.body)
        textField.adjustsFontForContentSizeCategory = true
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()

    private let loginButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Log In", for: .normal)
        button.backgroundColor = AppTheme.primary
        button.setTitleColor(AppTheme.primaryContrast, for: .normal)
        button.layer.cornerRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let facialRecognitionButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Log In with Face ID", for: .normal)
        button.backgroundColor = .clear
        button.setTitleColor(AppTheme.primary, for: .normal)
        button.layer.cornerRadius = 8
        button.layer.borderWidth = 1
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let createAccountButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Create New Account", for: .normal)
        button.setTitleColor(AppTheme.primary, for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let forgotPasswordButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Forgot Password?", for: .normal)
        button.setTitleColor(AppTheme.primary, for: .normal)
        button.titleLabel?.font = .preferredFont(forTextStyle: .subheadline)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
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
        view.backgroundColor = AppTheme.overlay
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()

    // MARK: - Properties
    var canCreateAccount = true {
        didSet { createAccountButton.isHidden = !canCreateAccount }
    }
    private var activeTextField: UITextField?
    private var isAuthenticating = false

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        #if DEBUG
        print("🔵 LoginViewController: viewDidLoad called")
        #endif
        setupUI()
        applyBiometricButtonBorder()
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (controller: Self, _: UITraitCollection) in
            controller.applyBiometricButtonBorder()
        }
        setupActions()
        setupKeyboardHandling()
        if UserDefaults.standard.bool(forKey: Self.biometricsExplainedKey) {
            checkBiometricAvailability()
        }
        createAccountButton.isHidden = !canCreateAccount
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
            transitionToMainApp()
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
            makeProductMark(),
            emailTextField,
            passwordTextField,
            loginButton,
            facialRecognitionButton,
            forgotPasswordButton,
            createAccountButton
        ])
        stackView.axis = .vertical
        stackView.spacing = AppTheme.spacing16
        stackView.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(stackView)
        view.addSubview(overlayView)
        overlayView.addSubview(activityIndicator)

        let stackCenterY = stackView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        stackCenterY.priority = .defaultLow

        NSLayoutConstraint.activate([
            // Scroll view constraints
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Content view constraints
            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            contentView.heightAnchor.constraint(greaterThanOrEqualTo: scrollView.frameLayoutGuide.heightAnchor),
            
            // Stack view constraints
            stackCenterY,
            stackView.topAnchor.constraint(greaterThanOrEqualTo: contentView.topAnchor, constant: AppTheme.spacing24),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -AppTheme.spacing24),
        ] + AppTheme.readableWidthConstraints(
            for: stackView,
            width: contentView.widthAnchor,
            centerX: contentView.centerXAnchor,
            leading: contentView.leadingAnchor,
            trailing: contentView.trailingAnchor,
            margin: 40
        ) + [

            // Button height constraints
            emailTextField.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            passwordTextField.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
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

    private func makeProductMark() -> UIView {
        let icon = UIImageView(image: UIImage(named: "LaunchIcon"))
        icon.contentMode = .scaleAspectFit
        icon.isAccessibilityElement = false
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 72).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 72).isActive = true

        let title = UILabel()
        title.text = "Pallet Rack Safety"
        title.font = AppTheme.fontBold(.largeTitle)
        title.adjustsFontForContentSizeCategory = true
        title.textAlignment = .center
        title.numberOfLines = 0
        title.textColor = AppTheme.textPrimary

        let mark = UIStackView(arrangedSubviews: [icon, title])
        mark.axis = .vertical
        mark.alignment = .center
        mark.spacing = AppTheme.spacing8
        return mark
    }

    private func applyBiometricButtonBorder() {
        facialRecognitionButton.layer.borderColor = AppTheme.primary.resolvedColor(with: traitCollection).cgColor
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
        
        loginButton.accessibilityLabel = "Log in"
        createAccountButton.accessibilityLabel = "Create new account"
        forgotPasswordButton.accessibilityLabel = "Forgot password"
    }
    
    private static let biometricsExplainedKey = "login.biometricsExplained"

    private func checkBiometricAvailability() {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            switch context.biometryType {
            case .faceID:
                facialRecognitionButton.setTitle("Log In with Face ID", for: .normal)
                facialRecognitionButton.accessibilityLabel = "Log in with Face ID"
            case .touchID:
                facialRecognitionButton.setTitle("Log In with Touch ID", for: .normal)
                facialRecognitionButton.accessibilityLabel = "Log in with Touch ID"
            case .opticID:
                facialRecognitionButton.setTitle("Log In with Optic ID", for: .normal)
                facialRecognitionButton.accessibilityLabel = "Log in with Optic ID"
            case .none:
                facialRecognitionButton.setTitle("Biometric Login", for: .normal)
                facialRecognitionButton.accessibilityLabel = "Biometric login"
            @unknown default:
                facialRecognitionButton.setTitle("Biometric Login", for: .normal)
                facialRecognitionButton.accessibilityLabel = "Biometric login"
            }
            facialRecognitionButton.isEnabled = true
        } else {
            facialRecognitionButton.setTitle("Biometric Login Unavailable", for: .normal)
            facialRecognitionButton.accessibilityLabel = "Biometric login unavailable"
            facialRecognitionButton.isEnabled = false
            facialRecognitionButton.backgroundColor = .systemGray2
        }
    }

    // MARK: - Actions
    @objc private func loginTapped() {
        #if DEBUG
        print("🔵 LoginViewController: Login button tapped")
        #endif
        
        // Prevent multiple simultaneous login attempts
        guard !isAuthenticating else {
            #if DEBUG
            print("🔵 LoginViewController: Authentication already in progress")
            #endif
            return
        }
        
        let email = emailTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let password = passwordTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !email.isEmpty, !password.isEmpty else {
            showAlert(title: "Error", message: "Please enter both email and password.")
            return
        }
        guard isValidEmail(email) else {
            showAlert(title: "Invalid Email", message: "Please enter a valid email address.")
            return
        }
        
        isAuthenticating = true
        showActivityIndicator(true)

        Task {
            let outcome = await SessionOpening.live.login(email: email, password: password)

            await MainActor.run {
                self.isAuthenticating = false

                switch outcome {
                case .started:
                    HapticManager.success()
                    Task {
                        await self.performSuccessfulLogin()
                    }
                case .waiting(let notice), .locked(let notice), .refused(let notice):
                    HapticManager.error()
                    self.showActivityIndicator(false)
                    self.showAlert(title: notice.title, message: notice.message)
                }
            }
        }
    }

    @objc private func facialRecognitionLoginTapped() {
        #if DEBUG
        print("🔵 LoginViewController: Face ID button tapped")
        #endif
        
        // Prevent multiple simultaneous login attempts
        guard !isAuthenticating else {
            #if DEBUG
            print("🔵 LoginViewController: Authentication already in progress")
            #endif
            return
        }
        
        guard UserManager.shared.lastUserId != nil else {
            showAlert(title: "No Account", message: "Please log in with email and password first to enable biometric authentication.")
            return
        }

        if !UserDefaults.standard.bool(forKey: Self.biometricsExplainedKey) {
            let alert = UIAlertController(
                title: "Face ID",
                message: "Systems Inspector uses Face ID or Touch ID to log you back in on this phone. iOS will ask for permission next.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "Not Now", style: .cancel))
            alert.addAction(UIAlertAction(title: "Continue", style: .default) { [weak self] _ in
                UserDefaults.standard.set(true, forKey: Self.biometricsExplainedKey)
                self?.evaluateBiometrics()
            })
            present(alert, animated: true)
            return
        }

        evaluateBiometrics()
    }

    private func evaluateBiometrics() {
        isAuthenticating = true
        
        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            checkBiometricAvailability()
            let reason = "Authenticate to log in to Systems Inspector"

            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { [weak self] success, authenticationError in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    
                    self.isAuthenticating = false
                    
                    if success {
                        HapticManager.success()
                        #if DEBUG
                        print("🔵 LoginViewController: Biometric authentication successful")
                        #endif
                        if UserManager.shared.completeBiometricLogin() {
                            Task {
                                await self.performSuccessfulLogin()
                            }
                        } else {
                            HapticManager.error()
                            self.showAlert(title: "Authentication Failed", message: "No account is available for biometric login.")
                        }
                    } else {
                        HapticManager.error()
                        let errorMessage = authenticationError?.localizedDescription ?? "Failed to authenticate with biometrics."
                        #if DEBUG
                        print("🔴 LoginViewController: Biometric authentication failed: \(errorMessage)")
                        #endif
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
        #if DEBUG
        print("🔵 LoginViewController: Create account button tapped")
        #endif
        
        let accountCreationVC = AccountCreationViewController()
        navigationController?.pushViewController(accountCreationVC, animated: true)
    }
    
    @objc private func forgotPasswordTapped() {
        #if DEBUG
        print("🔵 LoginViewController: Forgot password button tapped")
        #endif
        
        let forgotPasswordVC = ForgotPasswordViewController()
        let navController = UINavigationController(rootViewController: forgotPasswordVC)
        present(navController, animated: true)
    }

    private func performSuccessfulLogin() async {
        #if DEBUG
        print("🔵 LoginViewController: Performing successful login")
        #endif
        
        await MainActor.run {
            self.showActivityIndicator(false)
            self.showCheckmarkThenTransition()
        }
    }
    
    private func showCheckmarkThenTransition() {
        guard !UIAccessibility.isReduceMotionEnabled else {
            transitionToMainApp()
            return
        }
        
        let checkmarkView = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
        checkmarkView.tintColor = AppTheme.success
        checkmarkView.contentMode = .scaleAspectFit
        checkmarkView.translatesAutoresizingMaskIntoConstraints = false
        checkmarkView.alpha = 0
        checkmarkView.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
        
        view.addSubview(checkmarkView)
        NSLayoutConstraint.activate([
            checkmarkView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            checkmarkView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            checkmarkView.widthAnchor.constraint(equalToConstant: 80),
            checkmarkView.heightAnchor.constraint(equalToConstant: 80)
        ])
        
        UIView.animate(withDuration: 0.2, animations: {
            checkmarkView.alpha = 1
            checkmarkView.transform = .identity
        }) { _ in
            UIView.animate(withDuration: 0.25, delay: 0.25, options: [], animations: {
                checkmarkView.alpha = 0
            }) { _ in
                checkmarkView.removeFromSuperview()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.transitionToMainApp()
                }
            }
        }
    }
    
    private func transitionToMainApp() {
        guard let sceneDelegate = UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate,
              let window = sceneDelegate.window else { return }
        let mainTabBarController = MainTabBarController()
        window.rootViewController = mainTabBarController
        UIView.transition(with: window, duration: 0.5, options: .transitionCrossDissolve, animations: nil, completion: nil)
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
    
    private func isValidEmail(_ email: String) -> Bool {
        let pattern = #"[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,64}"#
        return email.range(of: pattern, options: .regularExpression) != nil
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
