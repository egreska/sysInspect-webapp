//
//  InspectionItemFormViewController.swift
//  Systems Inspector
//

import UIKit

protocol InspectionItemFormDelegate: AnyObject {
    func didSaveInspectionItem()
}

final class InspectionItemFormViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    weak var delegate: InspectionItemFormDelegate?

    private enum Mode {
        case create(InspectionFormViewModel)
        case edit(InspectionItem)
    }

    private let mode: Mode
    private var form: InspectionItemFormState
    private var activeTextField: UITextField?
    private var activeTextView: UITextView?

    private let addItemButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = AppTheme.primary
        button.tintColor = AppTheme.primaryContrast
        button.layer.cornerRadius = 30
        button.translatesAutoresizingMaskIntoConstraints = false
        let configuration = UIImage.SymbolConfiguration(pointSize: 24, weight: .medium)
        button.setImage(UIImage(systemName: "plus", withConfiguration: configuration), for: .normal)
        return button
    }()

    private let addItemLabel: UILabel = {
        let label = UILabel()
        label.text = "+ Item"
        label.font = AppTheme.font(.subheadline)
        label.textAlignment = .center
        label.isAccessibilityElement = false
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let exitButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Exit Inspection", for: .normal)
        button.backgroundColor = AppTheme.destructive
        button.setTitleColor(AppTheme.primaryContrast, for: .normal)
        button.layer.cornerRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

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
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    private let primaryLocationTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "Area/Aisle"
        textField.borderStyle = .roundedRect
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()

    private let primaryLocationErrorLabel: UILabel = {
        let label = UILabel()
        label.font = AppTheme.font(.footnote)
        label.textColor = AppTheme.destructive
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isHidden = true
        return label
    }()

    private let secondaryLocationTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "Bay/Level (Optional)"
        textField.borderStyle = .roundedRect
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()

    private let issueDropdownButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Select Issue", for: .normal)
        button.backgroundColor = UIColor.systemGray6
        button.setTitleColor(.systemBlue, for: .normal)
        button.layer.cornerRadius = 8
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.systemGray4.cgColor
        button.contentHorizontalAlignment = .left
        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.plain()
            config.title = "Select Issue"
            config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 0)
            button.configuration = config
        } else {
            button.titleEdgeInsets = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 0)
        }
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let selectedIssueLabel: UILabel = {
        let label = UILabel()
        label.text = "No issue selected"
        label.font = AppTheme.font(.subheadline)
        label.textColor = AppTheme.textSecondary
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let importanceToggleButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = UIColor.systemGray6
        button.layer.cornerRadius = 8
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.systemGray4.cgColor
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let commentsTextView: UITextView = {
        let textView = UITextView()
        textView.layer.borderWidth = 1
        textView.layer.borderColor = AppTheme.separator.cgColor
        textView.layer.cornerRadius = 5
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.text = "Enter comments here..."
        textView.textColor = AppTheme.placeholder
        return textView
    }()

    private let cameraButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = UIColor.systemBlue
        button.tintColor = AppTheme.primaryContrast
        button.layer.cornerRadius = 30
        button.translatesAutoresizingMaskIntoConstraints = false
        let configuration = UIImage.SymbolConfiguration(pointSize: 24, weight: .medium)
        button.setImage(UIImage(systemName: "camera.fill", withConfiguration: configuration), for: .normal)
        return button
    }()

    private let photoStripView = InspectionPhotoStripView()
    private let cameraLabel: UILabel = {
        let label = UILabel()
        label.text = "Take Photo"
        label.font = AppTheme.font(.subheadline)
        label.textAlignment = .center
        label.isAccessibilityElement = false
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    private lazy var cameraContainerView: UIView = createIconLabeledButton(button: cameraButton, label: cameraLabel)

    init(viewModel: InspectionFormViewModel) {
        self.mode = .create(viewModel)
        self.form = InspectionItemFormState()
        super.init(nibName: nil, bundle: nil)
    }

    init(inspectionItem: InspectionItem) {
        self.mode = .edit(inspectionItem)
        self.form = InspectionItemIntake.formState(from: inspectionItem)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private var hasContent: Bool {
        pullFieldsIntoForm()
        return form.hasContent
    }

    private func validatedForm() -> InspectionItemFormState? {
        pullFieldsIntoForm()
        if !form.isValid {
            primaryLocationErrorLabel.text = "Area/Aisle is required"
            primaryLocationErrorLabel.isHidden = false
            primaryLocationTextField.layer.borderWidth = 1
            primaryLocationTextField.layer.borderColor = AppTheme.destructive.cgColor
            primaryLocationTextField.layer.cornerRadius = 6
            primaryLocationTextField.becomeFirstResponder()
            return nil
        }
        clearPrimaryLocationValidationState()
        return form
    }

    private func reset() {
        primaryLocationTextField.text = ""
        secondaryLocationTextField.text = ""
        form.reset()
        updateSelectedIssueDisplay()
        updateImportanceToggleDisplay()
        showCommentsPlaceholder()
        refreshPhotoStrip()
        primaryLocationTextField.becomeFirstResponder()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppTheme.background
        setupUI()
        setupActions()
        setupKeyboardHandling()
        commentsTextView.delegate = self
        applyFormToFields()
        setupChrome()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        guard case .create(let viewModel) = mode, isMovingFromParent else { return }
        if !viewModel.isResuming(), !viewModel.hasInspectionItems() {
            viewModel.abandonIfEmpty()
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func setupUI() {
        view.backgroundColor = AppTheme.background
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(stackView)

        let primaryLocationContainer = createLabeledField(
            labelText: "Area/Aisle *",
            field: primaryLocationTextField,
            errorLabel: primaryLocationErrorLabel
        )
        let secondaryLocationContainer = createLabeledField(
            labelText: "Secondary Location (Bay/Level):",
            field: secondaryLocationTextField
        )
        photoStripView.delegate = self
        photoStripView.heightAnchor.constraint(equalToConstant: 80).isActive = true
        cameraButton.accessibilityLabel = "Take Photo"
        addItemButton.accessibilityLabel = "+ Item"

        [
            primaryLocationContainer,
            secondaryLocationContainer,
            createIssueContainer(),
            createImportanceContainer(),
            createLabeledField(labelText: "Comments:", field: commentsTextView),
            photoStripView
        ].forEach { stackView.addArrangedSubview($0) }

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
            commentsTextView.heightAnchor.constraint(equalToConstant: 100)
        ])
    }

    private func setupActions() {
        issueDropdownButton.addTarget(self, action: #selector(issueDropdownTapped), for: .touchUpInside)
        importanceToggleButton.addTarget(self, action: #selector(importanceToggleTapped), for: .touchUpInside)
        cameraButton.addTarget(self, action: #selector(cameraTapped), for: .touchUpInside)
    }

    private func setupChrome() {
        switch mode {
        case .create(let viewModel):
            setupCreateChrome(viewModel: viewModel)
        case .edit:
            setupEditChrome()
        }
    }

    private func setupCreateChrome(viewModel: InspectionFormViewModel) {
        if viewModel.isResuming() {
            let dateString = DateFormatters.format(viewModel.getInspectionDate(), using: DateFormatters.medium)
            title = "Resume Inspection - \(dateString)"
            exitButton.setTitle("Finish Inspection", for: .normal)
        } else {
            title = "Inspection Form"
            exitButton.setTitle("Exit Inspection", for: .normal)
        }

        let buttonsRow = UIStackView(arrangedSubviews: [
            cameraContainerView,
            createIconLabeledButton(button: addItemButton, label: addItemLabel)
        ])
        buttonsRow.axis = .horizontal
        buttonsRow.distribution = .fillEqually
        buttonsRow.alignment = .fill

        exitButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
        stackView.addArrangedSubview(buttonsRow)
        stackView.addArrangedSubview(exitButton)

        addItemButton.addTarget(self, action: #selector(addItemTapped), for: .touchUpInside)
        exitButton.addTarget(self, action: #selector(exitTapped), for: .touchUpInside)
    }

    private func setupEditChrome() {
        title = "Edit Item"
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelTapped)
        )
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .save,
            target: self,
            action: #selector(saveTapped)
        )
        stackView.addArrangedSubview(cameraContainerView)
    }

    @discardableResult
    private func persistValidatedForm() -> Bool {
        guard let form = validatedForm() else { return false }
        switch mode {
        case .create(let viewModel):
            InspectionItemIntake.create(into: viewModel.inspectionForNewItem(), form: form)
        case .edit(let item):
            InspectionItemIntake.update(item, form: form)
        }
        return true
    }

    @objc private func addItemTapped() {
        guard persistValidatedForm() else { return }
        reset()
        HapticManager.success()
        flashAddButtonSuccess()
        showTemporaryMessage("Item added successfully!")
    }

    private func flashAddButtonSuccess() {
        let originalBg = addItemButton.backgroundColor
        let originalTransform = addItemButton.transform
        UIView.animate(withDuration: 0.15, animations: {
            self.addItemButton.backgroundColor = AppTheme.success
            self.addItemButton.transform = originalTransform.scaledBy(x: 1.15, y: 1.15)
        }) { _ in
            UIView.animate(withDuration: 0.2) {
                self.addItemButton.backgroundColor = originalBg
                self.addItemButton.transform = originalTransform
            }
        }
    }

    @objc private func exitTapped() {
        if hasContent {
            let alert = UIAlertController(
                title: "Save Current Item?",
                message: "You have unsaved data. Would you like to save this item before exiting?",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "Save & Exit", style: .default) { [weak self] _ in
                guard let self else { return }
                _ = self.persistValidatedForm()
                self.finishInspection()
            })
            alert.addAction(UIAlertAction(title: "Exit Without Saving", style: .destructive) { [weak self] _ in
                self?.finishInspection()
            })
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            present(alert, animated: true)
        } else {
            finishInspection()
        }
    }

    private func finishInspection() {
        guard case .create(let viewModel) = mode else { return }
        viewModel.finish()
        NotificationCenter.default.post(name: .inspectionCompleted, object: nil)
        navigationController?.popViewController(animated: true)
    }

    private func showTemporaryMessage(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        present(alert, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            alert.dismiss(animated: true)
        }
    }

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }

    @objc private func saveTapped() {
        guard persistValidatedForm() else { return }
        delegate?.didSaveInspectionItem()
        dismiss(animated: true)
    }

    private func applyFormToFields() {
        primaryLocationTextField.text = form.location.isEmpty ? nil : form.location
        secondaryLocationTextField.text = form.bayNumber
        if let comments = form.comments, !comments.isEmpty {
            commentsTextView.text = comments
            commentsTextView.textColor = .label
        } else {
            showCommentsPlaceholder()
        }
        updateSelectedIssueDisplay()
        updateImportanceToggleDisplay()
        refreshPhotoStrip()
    }

    private func pullFieldsIntoForm() {
        form.location = primaryLocationTextField.text ?? ""
        form.bayNumber = secondaryLocationTextField.text
        if commentsTextView.textColor == AppTheme.placeholder || commentsTextView.text == "Enter comments here..." {
            form.comments = nil
        } else {
            form.comments = commentsTextView.text
        }
    }

    private func showCommentsPlaceholder() {
        commentsTextView.text = "Enter comments here..."
        commentsTextView.textColor = AppTheme.placeholder
    }

    private func createLabeledField(labelText: String, field: UIView, errorLabel: UILabel? = nil) -> UIView {
        let container = UIView()
        let label = UILabel()
        label.text = labelText
        label.font = UIFont.boldSystemFont(ofSize: 16)
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)
        container.addSubview(field)
        var constraints: [NSLayoutConstraint] = [
            label.topAnchor.constraint(equalTo: container.topAnchor),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            field.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 8),
            field.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            field.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ]
        if let err = errorLabel {
            container.addSubview(err)
            constraints += [
                err.topAnchor.constraint(equalTo: field.bottomAnchor, constant: 4),
                err.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                err.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                err.bottomAnchor.constraint(equalTo: container.bottomAnchor)
            ]
        } else {
            constraints.append(field.bottomAnchor.constraint(equalTo: container.bottomAnchor))
        }
        NSLayoutConstraint.activate(constraints)
        return container
    }

    private func createIssueContainer() -> UIView {
        let container = UIView()
        let label = UILabel()
        label.text = "Issue:"
        label.font = UIFont.boldSystemFont(ofSize: 16)
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)
        container.addSubview(issueDropdownButton)
        container.addSubview(selectedIssueLabel)
        issueDropdownButton.accessibilityLabel = "Issue type"
        issueDropdownButton.accessibilityHint = "Double tap to open issue picker"
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: container.topAnchor),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            issueDropdownButton.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 8),
            issueDropdownButton.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            issueDropdownButton.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            issueDropdownButton.heightAnchor.constraint(equalToConstant: 44),
            selectedIssueLabel.topAnchor.constraint(equalTo: issueDropdownButton.bottomAnchor, constant: 8),
            selectedIssueLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            selectedIssueLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            selectedIssueLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        return container
    }

    private func createImportanceContainer() -> UIView {
        let container = UIView()
        let label = UILabel()
        label.text = "Importance:"
        label.font = UIFont.boldSystemFont(ofSize: 16)
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)
        container.addSubview(importanceToggleButton)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: container.topAnchor),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            importanceToggleButton.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 8),
            importanceToggleButton.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            importanceToggleButton.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            importanceToggleButton.heightAnchor.constraint(equalToConstant: 44),
            importanceToggleButton.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        return container
    }

    private func createIconLabeledButton(button: UIButton, label: UILabel) -> UIView {
        let container = UIView()
        container.addSubview(button)
        container.addSubview(label)
        NSLayoutConstraint.activate([
            button.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            button.topAnchor.constraint(equalTo: container.topAnchor),
            button.widthAnchor.constraint(equalToConstant: 60),
            button.heightAnchor.constraint(equalToConstant: 60),
            label.topAnchor.constraint(equalTo: button.bottomAnchor, constant: 8),
            label.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            container.heightAnchor.constraint(equalToConstant: 90)
        ])
        return container
    }

    private func updateImportanceToggleDisplay() {
        let configuration = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        if form.importance == "Needs immediate attention" {
            importanceToggleButton.setImage(UIImage(systemName: "exclamationmark.triangle.fill", withConfiguration: configuration), for: .normal)
            importanceToggleButton.setTitle("  Needs immediate attention", for: .normal)
            importanceToggleButton.tintColor = .systemRed
            importanceToggleButton.setTitleColor(.systemRed, for: .normal)
        } else {
            importanceToggleButton.setImage(UIImage(systemName: "eye.fill", withConfiguration: configuration), for: .normal)
            importanceToggleButton.setTitle("  Monitor", for: .normal)
            importanceToggleButton.tintColor = .systemYellow
            importanceToggleButton.setTitleColor(.systemYellow, for: .normal)
        }
        importanceToggleButton.contentHorizontalAlignment = .left
        if #available(iOS 15.0, *) {
            var config = importanceToggleButton.configuration ?? UIButton.Configuration.plain()
            config.imagePadding = 8
            config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 0)
            importanceToggleButton.configuration = config
        } else {
            importanceToggleButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 0)
            importanceToggleButton.titleEdgeInsets = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 0)
        }
        importanceToggleButton.accessibilityLabel = "Importance"
        importanceToggleButton.accessibilityValue = form.importance
        importanceToggleButton.accessibilityHint = "Double tap to change"
    }

    private func updateSelectedIssueDisplay() {
        let labels = form.issueDisplayLabels
        if labels.isEmpty {
            selectedIssueLabel.text = "No issue selected"
            selectedIssueLabel.textColor = .systemGray
            issueDropdownButton.setTitle("Select Issue", for: .normal)
            issueDropdownButton.accessibilityValue = "No issue selected"
        } else {
            selectedIssueLabel.text = "Selected: " + labels.joined(separator: ", ")
            selectedIssueLabel.textColor = .label
            issueDropdownButton.setTitle("\(labels.count) issue(s) selected", for: .normal)
            issueDropdownButton.accessibilityValue = labels.joined(separator: ", ")
        }
    }

    private func refreshPhotoStrip() {
        photoStripView.setPhotos(form.photos)
        let atCap = form.atPhotoCap
        cameraContainerView.isHidden = atCap
        cameraLabel.text = form.photos.isEmpty ? "Take Photo" : "Add Photo"
        cameraButton.accessibilityLabel = cameraLabel.text
    }

    private func clearPrimaryLocationValidationState() {
        primaryLocationErrorLabel.isHidden = true
        primaryLocationErrorLabel.text = nil
        primaryLocationTextField.layer.borderWidth = 0
        primaryLocationTextField.layer.borderColor = nil
    }

    private func setupKeyboardHandling() {
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
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)
        primaryLocationTextField.delegate = self
        secondaryLocationTextField.delegate = self
    }

    @objc private func keyboardWillShow(notification: NSNotification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue,
              let animationDuration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval else {
            return
        }
        let keyboardHeight = keyboardFrame.cgRectValue.height
        let contentInsets = UIEdgeInsets(top: 0, left: 0, bottom: keyboardHeight + 20, right: 0)
        scrollView.contentInset = contentInsets
        scrollView.scrollIndicatorInsets = contentInsets
        let duration = UIAccessibility.isReduceMotionEnabled ? 0 : animationDuration
        UIView.animate(withDuration: duration) {
            if let activeField = self.activeTextField {
                self.scrollToField(activeField)
            } else if let activeTextView = self.activeTextView {
                self.scrollToField(activeTextView)
            }
        }
    }

    @objc private func keyboardWillHide(notification: NSNotification) {
        guard let animationDuration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval else {
            return
        }
        let duration = UIAccessibility.isReduceMotionEnabled ? 0 : animationDuration
        UIView.animate(withDuration: duration) {
            self.scrollView.contentInset = .zero
            self.scrollView.scrollIndicatorInsets = .zero
        }
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    private func scrollToField(_ field: UIView) {
        let fieldFrame = field.convert(field.bounds, to: scrollView)
        let targetRect = CGRect(
            x: fieldFrame.origin.x,
            y: fieldFrame.origin.y - 20,
            width: fieldFrame.width,
            height: fieldFrame.height + 40
        )
        scrollView.scrollRectToVisible(targetRect, animated: true)
    }

    @objc private func issueDropdownTapped() {
        let selectionVC = IssueSelectionViewController()
        selectionVC.selected = form.issues
        selectionVC.delegate = self
        present(UINavigationController(rootViewController: selectionVC), animated: true)
    }

    @objc private func importanceToggleTapped() {
        form.toggleImportance()
        updateImportanceToggleDisplay()
    }

    @objc private func cameraTapped() {
        guard !form.atPhotoCap else { return }
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            showAlert(message: "Camera is not available")
            return
        }
        let imagePicker = UIImagePickerController()
        imagePicker.sourceType = .camera
        imagePicker.cameraCaptureMode = .photo
        imagePicker.cameraDevice = .rear
        imagePicker.allowsEditing = false
        imagePicker.delegate = self
        present(imagePicker, animated: true)
    }

    private func showAlert(message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        if let image = info[.originalImage] as? UIImage {
            if image.jpegData(compressionQuality: 0.8) == nil {
                picker.dismiss(animated: true)
                showAlert(message: "Couldn't save that photo. Try taking it again.")
                return
            }
            if form.addPhoto(image) {
                refreshPhotoStrip()
            }
        }
        picker.dismiss(animated: true)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}

extension InspectionItemFormViewController: UITextViewDelegate {
    func textViewDidBeginEditing(_ textView: UITextView) {
        activeTextView = textView
        activeTextField = nil
        if textView.textColor == AppTheme.placeholder || textView.text == "Enter comments here..." {
            textView.text = ""
            textView.textColor = .label
        }
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        activeTextView = nil
        if textView.text.isEmpty {
            showCommentsPlaceholder()
        }
    }
}

extension InspectionItemFormViewController: IssueSelectionDelegate {
    func didSelectIssues(_ selected: Set<Issue.Path>) {
        form.issues = selected
        updateSelectedIssueDisplay()
        commentsTextView.becomeFirstResponder()
    }
}

extension InspectionItemFormViewController: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        activeTextField = textField
        activeTextView = nil
        if textField == primaryLocationTextField {
            clearPrimaryLocationValidationState()
        }
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        activeTextField = nil
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == primaryLocationTextField {
            secondaryLocationTextField.becomeFirstResponder()
        } else if textField == secondaryLocationTextField {
            commentsTextView.becomeFirstResponder()
        } else {
            textField.resignFirstResponder()
        }
        return true
    }
}

extension InspectionItemFormViewController: InspectionPhotoStripViewDelegate {
    func photoStripDidRemovePhoto(at index: Int) {
        form.removePhoto(at: index)
        refreshPhotoStrip()
    }

    func photoStripDidSelectPhoto(at index: Int) {
        guard form.photos.indices.contains(index) else { return }
        let preview = PhotoPreviewViewController(image: form.photos[index])
        present(UINavigationController(rootViewController: preview), animated: true)
    }
}
