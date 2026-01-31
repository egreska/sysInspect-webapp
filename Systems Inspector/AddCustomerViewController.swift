//
//  AddCustomerViewController.swift
//  Systems Inspector
//
//  Created by Eric Greska on 5/22/25.
//

import UIKit
import CoreData

class AddCustomerViewController: UIViewController {
    
    // MARK: - Properties
    weak var delegate: AddCustomerViewControllerDelegate?
    
    // Updated text fields for all customer inputs
    private let companyNameTextField = UITextField()
    private let siteTextField = UITextField()
    private let contactNameTextField = UITextField()
    private let phoneTextField = UITextField()
    private let addressTextField = UITextField()
    private let cityTextField = UITextField()
    private let stateTextField = UITextField()
    private let zipCodeTextField = UITextField()
    
    private let saveButton = UIButton(type: .system)
    private let cancelButton = UIButton(type: .system)
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    // Array to manage text field navigation
    private var textFields: [UITextField] = []
    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTextFields()
        setupUI()
        setupKeyboardHandling()
    }
    
    // MARK: - Text Field Setup
    private func setupTextFields() {
        // Configure Company Name TextField
        companyNameTextField.placeholder = "Company Name *"
        companyNameTextField.borderStyle = .roundedRect
        companyNameTextField.autocapitalizationType = .words
        companyNameTextField.returnKeyType = .next
        companyNameTextField.delegate = self
        companyNameTextField.translatesAutoresizingMaskIntoConstraints = false
        
        // Configure Site TextField
        siteTextField.placeholder = "Site"
        siteTextField.borderStyle = .roundedRect
        siteTextField.autocapitalizationType = .words
        siteTextField.returnKeyType = .next
        siteTextField.delegate = self
        siteTextField.translatesAutoresizingMaskIntoConstraints = false
        
        // Configure Contact Name TextField
        contactNameTextField.placeholder = "Contact Name"
        contactNameTextField.borderStyle = .roundedRect
        contactNameTextField.autocapitalizationType = .words
        contactNameTextField.returnKeyType = .next
        contactNameTextField.delegate = self
        contactNameTextField.translatesAutoresizingMaskIntoConstraints = false
        
        // Configure Phone TextField
        phoneTextField.placeholder = "Phone #"
        phoneTextField.borderStyle = .roundedRect
        phoneTextField.keyboardType = .phonePad
        phoneTextField.returnKeyType = .next
        phoneTextField.delegate = self
        phoneTextField.translatesAutoresizingMaskIntoConstraints = false
        
        // Configure Address TextField
        addressTextField.placeholder = "Address"
        addressTextField.borderStyle = .roundedRect
        addressTextField.returnKeyType = .next
        addressTextField.delegate = self
        addressTextField.translatesAutoresizingMaskIntoConstraints = false
        
        // Configure City TextField
        cityTextField.placeholder = "City"
        cityTextField.borderStyle = .roundedRect
        cityTextField.autocapitalizationType = .words
        cityTextField.returnKeyType = .next
        cityTextField.delegate = self
        cityTextField.translatesAutoresizingMaskIntoConstraints = false
        
        // Configure State TextField
        stateTextField.placeholder = "State"
        stateTextField.borderStyle = .roundedRect
        stateTextField.autocapitalizationType = .allCharacters
        stateTextField.returnKeyType = .next
        stateTextField.delegate = self
        stateTextField.translatesAutoresizingMaskIntoConstraints = false
        
        // Configure Zip Code TextField
        zipCodeTextField.placeholder = "Zip Code"
        zipCodeTextField.borderStyle = .roundedRect
        zipCodeTextField.keyboardType = .numberPad
        zipCodeTextField.returnKeyType = .done
        zipCodeTextField.delegate = self
        zipCodeTextField.translatesAutoresizingMaskIntoConstraints = false
        
        // Store text fields in order for navigation
        textFields = [
            companyNameTextField,
            siteTextField,
            contactNameTextField,
            phoneTextField,
            addressTextField,
            cityTextField,
            stateTextField,
            zipCodeTextField
        ]
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        title = "Add Customer"
        view.backgroundColor = .white
        
        // Setup ScrollView
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        // Add all text fields to content view
        textFields.forEach { contentView.addSubview($0) }
        
        // Setup Save Button
        saveButton.setTitle("Save Customer", for: .normal)
        saveButton.backgroundColor = .systemBlue
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.layer.cornerRadius = 8
        saveButton.addTarget(self, action: #selector(saveCustomer), for: .touchUpInside)
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(saveButton)
        
        // Setup Cancel Button
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.backgroundColor = .systemGray5
        cancelButton.setTitleColor(.systemBlue, for: .normal)
        cancelButton.layer.cornerRadius = 8
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(cancelButton)
        
        // Add a navigation bar "Cancel" button as well
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelTapped)
        )
        
        // Layout Constraints
        setupConstraints()
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])
        
        // Layout text fields in order
        var previousAnchor = contentView.topAnchor
        for (index, textField) in textFields.enumerated() {
            NSLayoutConstraint.activate([
                textField.topAnchor.constraint(equalTo: previousAnchor, constant: index == 0 ? 20 : 16),
                textField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
                textField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
                textField.heightAnchor.constraint(equalToConstant: 44)
            ])
            previousAnchor = textField.bottomAnchor
        }
        
        // Layout buttons
        NSLayoutConstraint.activate([
            saveButton.topAnchor.constraint(equalTo: previousAnchor, constant: 40),
            saveButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            saveButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            saveButton.heightAnchor.constraint(equalToConstant: 50),
            
            cancelButton.topAnchor.constraint(equalTo: saveButton.bottomAnchor, constant: 20),
            cancelButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            cancelButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            cancelButton.heightAnchor.constraint(equalToConstant: 50),
            cancelButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
    }
    
    private func setupKeyboardHandling() {
        // Add tap gesture to dismiss keyboard
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tapGesture)
        
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
    
    // MARK: - Actions
    @objc private func saveCustomer() {
        guard validateForm() else { return }

        guard let currentUserID = CoreDataManager.shared.currentUserID else {
            showAlert(message: "User not logged in. Cannot save customer.")
            return
        }
        
        let customer = Customer(context: CoreDataManager.shared.context)
        
        // ENSURE these are always set since they're now optional in the model
        customer.id = UUID()
        customer.createdDate = Date()
        customer.userId = currentUserID
        
        customer.name = companyNameTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        customer.site = siteTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        customer.contactName = contactNameTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        customer.phone = phoneTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        customer.address = addressTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        customer.city = cityTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        customer.state = stateTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        customer.zipCode = zipCodeTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines)

        print("💾 Saving customer locally with CloudKit sync")
        CoreDataManager.shared.saveContext()

        delegate?.didAddCustomer(customer)
        
        if let navigationController = navigationController {
            navigationController.dismiss(animated: true)
        } else {
            dismiss(animated: true)
        }
    }


    
    @objc private func cancelTapped() {
        if let navigationController = navigationController {
            navigationController.dismiss(animated: true)
        } else {
            dismiss(animated: true)
        }
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    @objc private func keyboardWillShow(notification: NSNotification) {
        guard let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue else {
            return
        }
        
        let contentInsets = UIEdgeInsets(top: 0, left: 0, bottom: keyboardSize.height, right: 0)
        scrollView.contentInset = contentInsets
        scrollView.scrollIndicatorInsets = contentInsets
        
        // Scroll to the active text field if needed
        if let activeField = findFirstResponder() {
            let aRect = self.view.convert(activeField.frame, from: activeField.superview)
            scrollView.scrollRectToVisible(aRect, animated: true)
        }
    }
    
    @objc private func keyboardWillHide(notification: NSNotification) {
        scrollView.contentInset = .zero
        scrollView.scrollIndicatorInsets = .zero
    }
    
    // MARK: - Helper Methods
    private func validateForm() -> Bool {
        guard let companyName = companyNameTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !companyName.isEmpty else {
            showAlert(message: "Please enter a company name.")
            companyNameTextField.becomeFirstResponder()
            return false
        }
        
        return true
    }
    
    private func showAlert(message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func findFirstResponder() -> UIView? {
        return findFirstResponder(in: view)
    }
    
    private func findFirstResponder(in view: UIView) -> UIView? {
        if view.isFirstResponder {
            return view
        }
        
        for subview in view.subviews {
            if let firstResponder = findFirstResponder(in: subview) {
                return firstResponder
            }
        }
        
        return nil
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
    
// MARK: - UITextFieldDelegate
extension AddCustomerViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if let currentIndex = textFields.firstIndex(of: textField) {
            if currentIndex < textFields.count - 1 {
                // Move to next text field
                textFields[currentIndex + 1].becomeFirstResponder()
            } else {
                // Last field, attempt to save
                textField.resignFirstResponder()
                saveCustomer()
            }
        }
        return true
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        // Format phone number - only allow digits
        if textField == phoneTextField {
            let allowedCharacters = CharacterSet(charactersIn: "0123456789")
            let characterSet = CharacterSet(charactersIn: string)
            return allowedCharacters.isSuperset(of: characterSet)
        }
        
        // Limit state field to 2 characters
        if textField == stateTextField {
            let currentText = textField.text ?? ""
            let newLength = currentText.count + string.count - range.length
            return newLength <= 2
        }
        
        // Limit zip code to 10 characters (for ZIP+4 format)
        if textField == zipCodeTextField {
            let currentText = textField.text ?? ""
            let newLength = currentText.count + string.count - range.length
            let allowedCharacters = CharacterSet(charactersIn: "0123456789-")
            let characterSet = CharacterSet(charactersIn: string)
            return newLength <= 10 && allowedCharacters.isSuperset(of: characterSet)
        }
        
        return true
    }
}

