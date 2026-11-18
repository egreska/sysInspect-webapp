//
//  InspectionItemFormViewController.swift
//  Systems Inspector
//

import AVFoundation
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
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        label.textAlignment = .center
        label.isAccessibilityElement = false
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let exitButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Exit Inspection", for: .normal)
        button.setTitleColor(AppTheme.primary, for: .normal)
        button.titleLabel?.font = AppTheme.fontMedium(.body)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.backgroundColor = .clear
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
        stackView.spacing = AppTheme.spacing16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    private let primaryLocationTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "Area/Aisle"
        textField.borderStyle = .roundedRect
        textField.font = AppTheme.font(.body)
        textField.adjustsFontForContentSizeCategory = true
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
        textField.font = AppTheme.font(.body)
        textField.adjustsFontForContentSizeCategory = true
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()

    private let issueDropdownButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Select Issue", for: .normal)
        button.backgroundColor = UIColor.systemGray6
        button.setTitleColor(AppTheme.primary, for: .normal)
        button.layer.cornerRadius = AppTheme.buttonCornerRadius
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.systemGray4.cgColor
        button.contentHorizontalAlignment = .left
        var config = UIButton.Configuration.plain()
        config.title = "Select Issue"
        config.baseForegroundColor = AppTheme.primary
        config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 0)
        button.configuration = config
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
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private var commentsMinHeight: NSLayoutConstraint?
    private let commentsTextView: UITextView = {
        let textView = UITextView()
        textView.layer.borderWidth = 1
        textView.layer.borderColor = AppTheme.separator.cgColor
        textView.layer.cornerRadius = AppTheme.buttonCornerRadius
        textView.font = AppTheme.font(.body)
        textView.adjustsFontForContentSizeCategory = true
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.text = "Enter comments here..."
        textView.textColor = AppTheme.placeholder
        return textView
    }()

    private let cameraButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = AppTheme.primary
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
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
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
        self.form = InspectionItemIntake.formState(from: inspectionItem, includingPhotos: false)
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
            primaryLocationTextField.layer.cornerRadius = AppTheme.buttonCornerRadius
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
        loadStoredPhotosIfNeeded()
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (controller: Self, _: UITraitCollection) in
            controller.updateCommentsMinHeight()
        }
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
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: AppTheme.spacing16),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -AppTheme.spacing16),
        ] + AppTheme.readableWidthConstraints(
            for: stackView,
            width: contentView.widthAnchor,
            centerX: contentView.centerXAnchor,
            leading: contentView.leadingAnchor,
            trailing: contentView.trailingAnchor,
            margin: AppTheme.spacing16
        ) + [
            commentsMinHeightConstraint()
        ])
        updateCommentsMinHeight()
    }

    private func commentsMinHeightConstraint() -> NSLayoutConstraint {
        let constraint = commentsTextView.heightAnchor.constraint(greaterThanOrEqualToConstant: 100)
        commentsMinHeight = constraint
        return constraint
    }

    private func updateCommentsMinHeight() {
        let lineHeight = AppTheme.font(.body).lineHeight
        let insets = commentsTextView.textContainerInset.top + commentsTextView.textContainerInset.bottom
        commentsMinHeight?.constant = max(100, (lineHeight * 4) + insets)
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

    private var isPersisting = false

    private func setPersisting(_ persisting: Bool) {
        isPersisting = persisting
        navigationItem.rightBarButtonItem?.isEnabled = !persisting
        addItemButton.isEnabled = !persisting
        exitButton.isEnabled = !persisting
        cameraButton.isEnabled = !persisting
        photoStripView.isUserInteractionEnabled = !persisting
    }

    private func persistValidatedForm() async -> Bool {
        guard let form = validatedForm() else { return false }
        switch mode {
        case .create(let viewModel):
            InspectionItemIntake.create(into: viewModel.inspectionForNewItem(), form: form)
        case .edit(let item):
            InspectionItemIntake.update(item, form: form)
        }
        return true
    }

    private func loadStoredPhotosIfNeeded() {
        guard case .edit(let item) = mode else { return }
        let bytes = item.photoBytes()
        guard !bytes.isEmpty else { return }
        cameraButton.isEnabled = false
        Task { @MainActor [weak self] in
            let stored = await InspectionItemIntake.storedPhotos(from: bytes)
            guard let self else { return }
            self.form.showStoredPhotos(stored)
            self.refreshPhotoStrip()
            if !self.isPersisting {
                self.cameraButton.isEnabled = true
            }
        }
    }

    @objc private func addItemTapped() {
        guard !isPersisting else { return }
        setPersisting(true)
        Task { @MainActor in
            let saved = await persistValidatedForm()
            setPersisting(false)
            guard saved else { return }
            reset()
            HapticManager.success()
            flashAddButtonSuccess()
            showTemporaryMessage("Item added successfully!")
        }
    }

    private func flashAddButtonSuccess() {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
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
                guard let self, !self.isPersisting else { return }
                self.setPersisting(true)
                Task { @MainActor in
                    let saved = await self.persistValidatedForm()
                    self.setPersisting(false)
                    guard saved else { return }
                    self.finishInspection()
                }
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
        guard !isPersisting else { return }
        setPersisting(true)
        Task { @MainActor in
            let saved = await persistValidatedForm()
            setPersisting(false)
            guard saved else { return }
            delegate?.didSaveInspectionItem()
            dismiss(animated: true)
        }
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
        label.font = AppTheme.fieldLabel()
        label.adjustsFontForContentSizeCategory = true
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
                err.topAnchor.constraint(equalTo: field.bottomAnchor, constant: AppTheme.spacing8),
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
        label.font = AppTheme.fieldLabel()
        label.adjustsFontForContentSizeCategory = true
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)
        container.addSubview(issueDropdownButton)
        container.addSubview(selectedIssueLabel)
        issueDropdownButton.accessibilityLabel = "Issue type"
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
        label.font = AppTheme.fieldLabel()
        label.adjustsFontForContentSizeCategory = true
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
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            container.heightAnchor.constraint(greaterThanOrEqualToConstant: 90)
        ])
        return container
    }

    private func updateImportanceToggleDisplay() {
        let urgent = form.importance.isImmediate
        let stateColor = urgent ? AppTheme.attention : AppTheme.monitor
        let titleColor = urgent ? AppTheme.attention : AppTheme.textPrimary
        let symbolName = urgent ? "exclamationmark.triangle.fill" : "eye.fill"
        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        let image = UIImage(systemName: symbolName, withConfiguration: symbolConfig)?
            .withTintColor(stateColor, renderingMode: .alwaysOriginal)

        importanceToggleButton.accessibilityLabel = "Importance"
        importanceToggleButton.accessibilityValue = form.importance.phrase
        importanceToggleButton.contentHorizontalAlignment = .left

        var config = UIButton.Configuration.plain()
        config.title = form.importance.phrase
        config.image = image
        config.imagePadding = 8
        config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12)
        config.baseForegroundColor = titleColor
        config.background.backgroundColor = stateColor.withAlphaComponent(0.15)
        config.background.cornerRadius = 8
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = AppTheme.font(.body)
            return outgoing
        }
        importanceToggleButton.configuration = config
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
        photoStripView.setPhotos(form.photos.map(\.image))
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
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            presentInspectionCamera()
        case .notDetermined:
            let alert = UIAlertController(
                title: "Camera",
                message: "Systems Inspector uses the camera to photograph this inspection item. iOS will ask for access next.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "Not Now", style: .cancel))
            alert.addAction(UIAlertAction(title: "Continue", style: .default) { [weak self] _ in
                self?.requestInspectionCamera()
            })
            present(alert, animated: true)
        case .denied, .restricted:
            presentInspectionCameraSettingsAlert()
        @unknown default:
            showAlert(message: "Camera is not available")
        }
    }

    private func requestInspectionCamera() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                guard let self else { return }
                guard granted else {
                    self.presentInspectionCameraSettingsAlert()
                    return
                }
                self.presentInspectionCamera()
            }
        }
    }

    private func presentInspectionCameraSettingsAlert() {
        let alert = UIAlertController(
            title: "Camera Access",
            message: "Enable camera access in Settings to photograph this inspection item.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            UIApplication.shared.open(url)
        })
        present(alert, animated: true)
    }

    private func presentInspectionCamera() {
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
        picker.dismiss(animated: true)
        guard let image = info[.originalImage] as? UIImage else { return }
        Task { @MainActor in
            guard let prepared = await StoredPhoto.prepared(from: image) else {
                showAlert(message: "Couldn't save that photo. Try taking it again.")
                return
            }
            if form.addPhoto(image: prepared.image, jpeg: prepared.jpeg) {
                refreshPhotoStrip()
            }
        }
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
        let preview = PhotoPreviewViewController(image: form.photos[index].image)
        present(UINavigationController(rootViewController: preview), animated: true)
    }
}
