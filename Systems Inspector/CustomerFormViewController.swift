//
//  CustomerFormViewController.swift
//  Systems Inspector
//

import UIKit

protocol CustomerFormDelegate: AnyObject {
    func didSaveCustomer(_ customer: Customer, isNew: Bool)
}

final class CustomerFormViewController: UIViewController {
    weak var delegate: CustomerFormDelegate?

    private let existing: Customer?
    private var form: CustomerFormState
    private var textFields: [UITextField] = []

    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        return scrollView
    }()
    private let contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let companyNameTextField = UITextField()
    private let companyNameErrorLabel: UILabel = {
        let label = UILabel()
        label.font = AppTheme.font(.footnote)
        label.textColor = AppTheme.destructive
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isHidden = true
        return label
    }()
    private let siteTextField = UITextField()
    private let contactNameTextField = UITextField()
    private let phoneTextField = UITextField()
    private let addressTextField = UITextField()
    private let cityTextField = UITextField()
    private let stateTextField = UITextField()
    private let zipCodeTextField = UITextField()
    private let siteRackingButton = UIButton(type: .system)
    private let siteRackingSubtitleLabel: UILabel = {
        let label = UILabel()
        label.font = AppTheme.font(.footnote)
        label.textColor = AppTheme.textSecondary
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    init(customer: Customer? = nil) {
        self.existing = customer
        self.form = customer.map { CustomerIntake.formState(from: $0) } ?? CustomerFormState()
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = existing == nil ? "Add Customer" : "Edit Customer"
        view.backgroundColor = AppTheme.background
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelTapped)
        )
        let saveItem = UIBarButtonItem(
            barButtonSystemItem: .save,
            target: self,
            action: #selector(saveTapped)
        )
        saveItem.accessibilityLabel = "Save customer"
        navigationItem.rightBarButtonItem = saveItem
        setupTextFields()
        setupUI()
        setupKeyboardHandling()
        applyFormToFields()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func setupTextFields() {
        configure(companyNameTextField, placeholder: "Company Name *", autocapitalization: .words)
        configure(siteTextField, placeholder: "Site", autocapitalization: .words)
        configure(contactNameTextField, placeholder: "Contact Name", autocapitalization: .words)
        configure(phoneTextField, placeholder: "Phone #")
        phoneTextField.keyboardType = .phonePad
        phoneTextField.textContentType = .telephoneNumber
        configure(addressTextField, placeholder: "Address")
        configure(cityTextField, placeholder: "City", autocapitalization: .words)
        configure(stateTextField, placeholder: "State", autocapitalization: .allCharacters)
        configure(zipCodeTextField, placeholder: "Zip Code")
        zipCodeTextField.keyboardType = .numberPad
        zipCodeTextField.textContentType = .postalCode
        zipCodeTextField.returnKeyType = .done
        siteRackingButton.setTitle("Site racking & documents", for: .normal)
        siteRackingButton.contentHorizontalAlignment = .left
        siteRackingButton.titleLabel?.font = AppTheme.font(.body)
        siteRackingButton.translatesAutoresizingMaskIntoConstraints = false
        siteRackingButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        siteRackingButton.accessibilityLabel = "Site racking and documents"
        siteRackingButton.addTarget(self, action: #selector(siteRackingTapped), for: .touchUpInside)
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

    private func configure(
        _ textField: UITextField,
        placeholder: String,
        autocapitalization: UITextAutocapitalizationType = .sentences
    ) {
        textField.placeholder = placeholder
        textField.borderStyle = .roundedRect
        textField.autocapitalizationType = autocapitalization
        textField.returnKeyType = .next
        textField.delegate = self
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.heightAnchor.constraint(equalToConstant: 44).isActive = true
    }

    private func setupUI() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(stackView)
        [
            sectionHeader("Company"),
            companyNameTextField,
            companyNameErrorLabel,
            siteTextField,
            sectionHeader("Contact"),
            contactNameTextField,
            phoneTextField,
            sectionHeader("Address"),
            addressTextField,
            cityTextField,
            stateTextField,
            zipCodeTextField,
            sectionHeader("Site"),
            siteRackingButton,
            siteRackingSubtitleLabel
        ].forEach { stackView.addArrangedSubview($0) }
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
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
    }

    private func sectionHeader(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = AppTheme.fontBold(.subheadline)
        label.textColor = AppTheme.textSecondary
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    private func applyFormToFields() {
        companyNameTextField.text = form.name.isEmpty ? nil : form.name
        siteTextField.text = form.site
        contactNameTextField.text = form.contactName
        phoneTextField.text = form.phone
        addressTextField.text = form.address
        cityTextField.text = form.city
        stateTextField.text = form.state
        zipCodeTextField.text = form.zipCode
        updateSiteRackingSubtitle()
    }

    private func updateSiteRackingSubtitle() {
        siteRackingSubtitleLabel.text = form.siteRackingSubtitle
    }

    @objc private func siteRackingTapped() {
        let sheet = SiteRackingViewController(
            siteRacking: form.siteRacking,
            siteDocuments: form.siteDocuments
        ) { [weak self] racking, docs in
            guard let self else { return }
            self.form.siteRacking = racking
            self.form.siteDocuments = docs
            self.updateSiteRackingSubtitle()
        }
        navigationController?.pushViewController(sheet, animated: true)
    }

    private func pullFieldsIntoForm() {
        form.name = companyNameTextField.text ?? ""
        form.site = siteTextField.text
        form.contactName = contactNameTextField.text
        form.phone = phoneTextField.text
        form.address = addressTextField.text
        form.city = cityTextField.text
        form.state = stateTextField.text
        form.zipCode = zipCodeTextField.text
    }

    private func validatedForm() -> CustomerFormState? {
        pullFieldsIntoForm()
        if !form.isValid {
            companyNameErrorLabel.text = "Company name is required"
            companyNameErrorLabel.isHidden = false
            companyNameTextField.layer.borderWidth = 1
            companyNameTextField.layer.borderColor = AppTheme.destructive.cgColor
            companyNameTextField.layer.cornerRadius = 6
            companyNameTextField.becomeFirstResponder()
            return nil
        }
        clearCompanyNameValidationState()
        return form
    }

    private func clearCompanyNameValidationState() {
        companyNameErrorLabel.isHidden = true
        companyNameTextField.layer.borderWidth = 0
        companyNameTextField.layer.borderColor = UIColor.clear.cgColor
    }

    private func setupKeyboardHandling() {
        addKeyboardToolbarToTextFields()
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
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

    private func addKeyboardToolbarToTextFields() {
        for (index, textField) in textFields.enumerated() {
            let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 44))
            toolbar.sizeToFit()
            let prev = UIBarButtonItem(title: "Previous", style: .plain, target: self, action: #selector(keyboardToolbarPrevious))
            let nextBtn = UIBarButtonItem(title: "Next", style: .plain, target: self, action: #selector(keyboardToolbarNext))
            let done = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(dismissKeyboard))
            prev.isEnabled = index > 0
            nextBtn.isEnabled = index < textFields.count - 1
            toolbar.items = [prev, nextBtn, UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil), done]
            textField.inputAccessoryView = toolbar
        }
    }

    @objc private func keyboardToolbarPrevious() {
        guard let first = findFirstResponder() as? UITextField,
              let idx = textFields.firstIndex(of: first),
              idx > 0 else { return }
        textFields[idx - 1].becomeFirstResponder()
    }

    @objc private func keyboardToolbarNext() {
        guard let first = findFirstResponder() as? UITextField,
              let idx = textFields.firstIndex(of: first),
              idx < textFields.count - 1 else { return }
        textFields[idx + 1].becomeFirstResponder()
    }

    @objc private func saveTapped() {
        guard let form = validatedForm() else { return }
        if let customer = existing {
            guard customer.userId != nil else {
                showAlert(message: "Customer record is missing user ID. Cannot save changes to cloud.")
                return
            }
            guard CustomerIntake.update(customer, form: form) else {
                HapticManager.error()
                showAlert(message: "Could not save customer. Please try again.")
                return
            }
            HapticManager.success()
            delegate?.didSaveCustomer(customer, isNew: false)
        } else {
            guard UserManager.shared.sessionUserId != nil else {
                showAlert(message: "User not logged in. Cannot save customer.")
                return
            }
            guard let customer = CustomerIntake.create(form: form) else {
                HapticManager.error()
                showAlert(message: "Could not save customer. Please try again.")
                return
            }
            HapticManager.success()
            delegate?.didSaveCustomer(customer, isNew: true)
        }
        dismiss(animated: true)
    }

    @objc private func cancelTapped() {
        dismiss(animated: true)
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
        if let activeField = findFirstResponder() {
            let aRect = view.convert(activeField.frame, from: activeField.superview)
            scrollView.scrollRectToVisible(aRect, animated: true)
        }
    }

    @objc private func keyboardWillHide(notification: NSNotification) {
        scrollView.contentInset = .zero
        scrollView.scrollIndicatorInsets = .zero
    }

    private func showAlert(message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func findFirstResponder() -> UIView? {
        findFirstResponder(in: view)
    }

    private func findFirstResponder(in view: UIView) -> UIView? {
        if view.isFirstResponder { return view }
        for subview in view.subviews {
            if let firstResponder = findFirstResponder(in: subview) {
                return firstResponder
            }
        }
        return nil
    }

    private func lookupZipCodeIfNeeded() {
        let zip = zipCodeTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: CharacterSet.decimalDigits.inverted).joined() ?? ""
        guard zip.count >= 5 else { return }
        let fiveDigit = String(zip.prefix(5))
        if let (city, state) = ZipCodeLookup.cityState(for: fiveDigit) {
            if cityTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true {
                cityTextField.text = city
            }
            if stateTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true {
                stateTextField.text = state
            }
        }
    }
}

extension CustomerFormViewController: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        if textField == companyNameTextField {
            clearCompanyNameValidationState()
        }
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if let currentIndex = textFields.firstIndex(of: textField) {
            if currentIndex < textFields.count - 1 {
                textFields[currentIndex + 1].becomeFirstResponder()
            } else {
                textField.resignFirstResponder()
                saveTapped()
            }
        }
        return true
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        if textField == zipCodeTextField {
            lookupZipCodeIfNeeded()
        }
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if textField == phoneTextField {
            let allowedCharacters = CharacterSet(charactersIn: "0123456789")
            return allowedCharacters.isSuperset(of: CharacterSet(charactersIn: string))
        }
        if textField == stateTextField {
            let currentText = textField.text ?? ""
            return currentText.count + string.count - range.length <= 2
        }
        if textField == zipCodeTextField {
            let currentText = textField.text ?? ""
            let newLength = currentText.count + string.count - range.length
            let allowedCharacters = CharacterSet(charactersIn: "0123456789-")
            return newLength <= 10 && allowedCharacters.isSuperset(of: CharacterSet(charactersIn: string))
        }
        return true
    }
}
