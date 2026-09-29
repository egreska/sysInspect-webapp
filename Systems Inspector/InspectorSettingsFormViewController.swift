//
//  InspectorSettingsFormViewController.swift
//  Systems Inspector
//

import UIKit

/// Sheet editor for inspector name and company details.
/// Replaces the alert dialogs whose text fields sat flush with the alert edges.
final class InspectorSettingsFormViewController: UIViewController {

    enum Form {
        case inspectorName
        case companyInformation
    }

    private let form: Form
    private let onSaved: () -> Void

    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.keyboardDismissMode = .interactive
        scrollView.alwaysBounceVertical = true
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

    private var textFields: [UITextField] = []

    init(form: Form, onSaved: @escaping () -> Void) {
        self.form = form
        self.onSaved = onSaved
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppTheme.background
        navigationItem.largeTitleDisplayMode = .never
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
        navigationItem.rightBarButtonItem = saveItem

        switch form {
        case .inspectorName:
            title = "Inspector Name"
            saveItem.accessibilityLabel = "Save inspector name"
            buildInspectorNameForm()
        case .companyInformation:
            title = "Company Information"
            saveItem.accessibilityLabel = "Save company information"
            buildCompanyForm()
        }

        installLayout()
        installKeyboardHandling()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Forms

    private func buildInspectorNameForm() {
        let nameField = makeTextField(
            placeholder: "Your Name",
            accessibilityLabel: "Your Name",
            text: UserDefaults.standard.string(forKey: "inspectorName"),
            capitalization: .words,
            contentType: .name
        )
        nameField.returnKeyType = .done
        textFields = [nameField]
        stackView.addArrangedSubview(introLabel("Enter your name to display on inspection reports"))
        stackView.addArrangedSubview(nameField)
    }

    private func buildCompanyForm() {
        let companyName = makeTextField(
            placeholder: "Company Name",
            accessibilityLabel: "Company Name",
            text: UserDefaults.standard.string(forKey: "companyName"),
            capitalization: .words,
            contentType: .organizationName
        )
        let street = makeTextField(
            placeholder: "Street Address",
            accessibilityLabel: "Street Address",
            text: UserDefaults.standard.string(forKey: "companyAddress"),
            capitalization: .words,
            contentType: .streetAddressLine1
        )
        let city = makeTextField(
            placeholder: "City",
            accessibilityLabel: "City",
            text: UserDefaults.standard.string(forKey: "companyCity"),
            capitalization: .words,
            contentType: .addressCity
        )
        let state = makeTextField(
            placeholder: "State",
            accessibilityLabel: "State",
            text: UserDefaults.standard.string(forKey: "companyState"),
            capitalization: .allCharacters,
            contentType: .addressState
        )
        let zip = makeTextField(
            placeholder: "ZIP Code",
            accessibilityLabel: "ZIP Code",
            text: UserDefaults.standard.string(forKey: "companyZipCode"),
            capitalization: .none,
            contentType: .postalCode
        )
        zip.keyboardType = .numberPad
        let phone = makeTextField(
            placeholder: "Phone Number",
            accessibilityLabel: "Phone Number",
            text: UserDefaults.standard.string(forKey: "companyPhone"),
            capitalization: .none,
            contentType: .telephoneNumber
        )
        phone.keyboardType = .phonePad
        phone.returnKeyType = .done

        textFields = [companyName, street, city, state, zip, phone]
        stackView.addArrangedSubview(introLabel("Enter your company details to display on reports"))
        addSection("Company", fields: [companyName])
        addSection("Address", fields: [street, city, state, zip])
        addSection("Contact", fields: [phone])
    }

    private func addSection(_ title: String, fields: [UIView]) {
        let header = sectionHeader(title)
        stackView.addArrangedSubview(header)
        stackView.setCustomSpacing(8, after: header)
        fields.forEach { stackView.addArrangedSubview($0) }
    }

    private func installLayout() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(stackView)
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

    private func makeTextField(
        placeholder: String,
        accessibilityLabel: String,
        text: String?,
        capitalization: UITextAutocapitalizationType,
        contentType: UITextContentType
    ) -> UITextField {
        let textField = UITextField()
        textField.placeholder = placeholder
        textField.accessibilityLabel = accessibilityLabel
        textField.text = text
        textField.borderStyle = .roundedRect
        textField.font = AppTheme.font(.body)
        textField.adjustsFontForContentSizeCategory = true
        textField.autocapitalizationType = capitalization
        textField.textContentType = contentType
        textField.returnKeyType = .next
        textField.delegate = self
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        return textField
    }

    private func introLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = AppTheme.font(.subheadline)
        label.textColor = AppTheme.textSecondary
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        return label
    }

    private func sectionHeader(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = AppTheme.fontBold(.subheadline)
        label.textColor = AppTheme.textSecondary
        label.adjustsFontForContentSizeCategory = true
        label.accessibilityTraits = .header
        return label
    }

    // MARK: - Keyboard

    private func installKeyboardHandling() {
        if textFields.count > 1 {
            addKeyboardToolbar()
        }
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

    private func addKeyboardToolbar() {
        for (index, textField) in textFields.enumerated() {
            let toolbar = UIToolbar()
            toolbar.sizeToFit()
            let previous = UIBarButtonItem(title: "Previous", style: .plain, target: self, action: #selector(focusPreviousField))
            let next = UIBarButtonItem(title: "Next", style: .plain, target: self, action: #selector(focusNextField))
            let done = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(dismissKeyboard))
            previous.isEnabled = index > 0
            next.isEnabled = index < textFields.count - 1
            toolbar.items = [
                previous,
                next,
                UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
                done
            ]
            textField.inputAccessoryView = toolbar
        }
    }

    @objc private func focusPreviousField() {
        guard let current = textFields.first(where: { $0.isFirstResponder }),
              let index = textFields.firstIndex(of: current),
              index > 0 else { return }
        textFields[index - 1].becomeFirstResponder()
    }

    @objc private func focusNextField() {
        guard let current = textFields.first(where: { $0.isFirstResponder }),
              let index = textFields.firstIndex(of: current),
              index < textFields.count - 1 else { return }
        textFields[index + 1].becomeFirstResponder()
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    @objc private func keyboardWillShow(_ notification: Notification) {
        navigationController?.sheetPresentationController?.animateChanges {
            self.navigationController?.sheetPresentationController?.selectedDetentIdentifier = .large
        }
        guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        let keyboardInView = view.convert(frame, from: nil)
        let overlap = max(0, view.bounds.maxY - keyboardInView.minY - view.safeAreaInsets.bottom)
        let insets = UIEdgeInsets(top: 0, left: 0, bottom: overlap, right: 0)
        let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25
        UIView.animate(withDuration: duration) {
            self.scrollView.contentInset = insets
            self.scrollView.scrollIndicatorInsets = insets
        }
        if let active = textFields.first(where: { $0.isFirstResponder }) {
            let rect = scrollView.convert(active.bounds, from: active).insetBy(dx: 0, dy: -12)
            scrollView.scrollRectToVisible(rect, animated: true)
        }
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25
        UIView.animate(withDuration: duration) {
            self.scrollView.contentInset = .zero
            self.scrollView.scrollIndicatorInsets = .zero
        }
    }

    // MARK: - Actions

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }

    @objc private func saveTapped() {
        switch form {
        case .inspectorName:
            let name = textFields.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !name.isEmpty else {
                dismiss(animated: true)
                return
            }
            UserDefaults.standard.set(name, forKey: "inspectorName")
        case .companyInformation:
            let values = textFields.map { $0.text ?? "" }
            guard values.count == 6 else { return }
            if !values[0].isEmpty {
                UserDefaults.standard.set(values[0], forKey: "companyName")
            }
            UserDefaults.standard.set(values[1], forKey: "companyAddress")
            UserDefaults.standard.set(values[2], forKey: "companyCity")
            UserDefaults.standard.set(values[3], forKey: "companyState")
            UserDefaults.standard.set(values[4], forKey: "companyZipCode")
            UserDefaults.standard.set(values[5], forKey: "companyPhone")
        }
        HapticManager.success()
        onSaved()
        dismiss(animated: true)
    }
}

extension InspectorSettingsFormViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        guard let index = textFields.firstIndex(of: textField) else { return true }
        if index < textFields.count - 1 {
            textFields[index + 1].becomeFirstResponder()
        } else {
            textField.resignFirstResponder()
            saveTapped()
        }
        return true
    }
}
