//
//  InspectionFormViewController.swift
//  Systems Inspector
//
//  Created by Eric Greska on 5/22/25.
import UIKit
import CoreData

class InspectionFormViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    // MARK: - Properties
    var viewModel: InspectionFormViewModel?
    private var photoURL: URL?
    private var selectedComponents: [DamageComponent] = []
    private var currentImportance: String = "Monitor" // Default value
    private var activeTextField: UITextField?
    private var activeTextView: UITextView?
    
    // MARK: - UI Components
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
        button.titleEdgeInsets = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 0)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let selectedIssueLabel: UILabel = {
        let label = UILabel()
        label.text = "No issue selected"
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = .systemGray
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // NEW: Importance toggle button
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
        textView.layer.borderColor = UIColor.lightGray.cgColor
        textView.layer.cornerRadius = 5
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.text = "Enter comments here..."
        textView.textColor = UIColor.lightGray
        return textView
    }()
    
    private let cameraButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = UIColor.systemBlue
        button.tintColor = .white
        button.layer.cornerRadius = 30
        button.translatesAutoresizingMaskIntoConstraints = false
        
        let configuration = UIImage.SymbolConfiguration(pointSize: 24, weight: .medium)
        let cameraImage = UIImage(systemName: "camera.fill", withConfiguration: configuration)
        button.setImage(cameraImage, for: .normal)
        
        return button
    }()
    
    private let addItemButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = UIColor.systemBlue
        button.tintColor = .white
        button.layer.cornerRadius = 30
        button.translatesAutoresizingMaskIntoConstraints = false
        
        let configuration = UIImage.SymbolConfiguration(pointSize: 24, weight: .medium)
        let plusImage = UIImage(systemName: "plus", withConfiguration: configuration)
        button.setImage(plusImage, for: .normal)
        
        return button
    }()
    
    private let exitButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Exit Inspection", for: .normal)
        button.backgroundColor = UIColor.systemRed
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private var damageHierarchy: [DamageComponent] = []
    
    // MARK: - Lifecycle Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        setupActions()
        setupDamageComponents()
        setupTextViewDelegate()
        setupKeyboardHandling()
        updateImportanceToggleDisplay() // Initialize the toggle display
        
        // NEW: Update title based on whether we're resuming or starting new
        updateNavigationTitle()
    }
   
    private func updateNavigationTitle() {
        if let viewModel = viewModel, viewModel.isResuming() {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            let dateString = dateFormatter.string(from: viewModel.getInspectionDate())
            title = "Resume Inspection - \(dateString)"
            
            // Update exit button text for resuming
            exitButton.setTitle("Finish Inspection", for: .normal)
        } else {
            title = "Inspection Form"
            exitButton.setTitle("Exit Inspection", for: .normal)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Only cancel if this is a new inspection with no items
        if isMovingFromParent, let viewModel = viewModel, !viewModel.isResuming(), !viewModel.hasInspectionItems() {
            viewModel.cancelInspection()
        }
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = .white
        title = "Inspection Form"
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(stackView)
        
        // UPDATED: Create fields in the new order with Importance added
        let primaryLocationContainer = createLabeledField(labelText: "Primary Location (Area/Aisle):", field: primaryLocationTextField)
        let secondaryLocationContainer = createLabeledField(labelText: "Secondary Location (Bay/Level):", field: secondaryLocationTextField)
        let issueContainer = createIssueContainer()
        let importanceContainer = createImportanceContainer() // NEW
        let commentsContainer = createLabeledField(labelText: "Comments:", field: commentsTextView)
        
        let buttonContainer = createButtonContainer()
        
        [primaryLocationContainer,
         secondaryLocationContainer,
         issueContainer,
         importanceContainer, // NEW: Added importance between issue and comments
         commentsContainer,
         buttonContainer,
         exitButton].forEach { stackView.addArrangedSubview($0) }
        
        stackView.setCustomSpacing(32, after: buttonContainer)
    }
    
    // NEW: Create importance container
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
    
    // NEW: Update importance toggle display
    private func updateImportanceToggleDisplay() {
        let configuration = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        
        if currentImportance == "Needs immediate attention" {
            let triangleImage = UIImage(systemName: "exclamationmark.triangle.fill", withConfiguration: configuration)
            importanceToggleButton.setImage(triangleImage, for: .normal)
            importanceToggleButton.setTitle("  Needs immediate attention", for: .normal)
            importanceToggleButton.tintColor = .systemRed
            importanceToggleButton.setTitleColor(.systemRed, for: .normal)
        } else {
            let eyeImage = UIImage(systemName: "eye.fill", withConfiguration: configuration)
            importanceToggleButton.setImage(eyeImage, for: .normal)
            importanceToggleButton.setTitle("  Monitor", for: .normal)
            importanceToggleButton.tintColor = .systemYellow
            importanceToggleButton.setTitleColor(.systemYellow, for: .normal)
        }
        
        importanceToggleButton.contentHorizontalAlignment = .left
        importanceToggleButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 0)
        importanceToggleButton.titleEdgeInsets = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 0)
    }
    
    private func createButtonContainer() -> UIView {
        let container = UIView()
        
        let cameraLabel = UILabel()
        cameraLabel.text = "Take Photo"
        cameraLabel.font = UIFont.systemFont(ofSize: 14)
        cameraLabel.textAlignment = .center
        cameraLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let addItemLabel = UILabel()
        addItemLabel.text = "+ Item"
        addItemLabel.font = UIFont.systemFont(ofSize: 14)
        addItemLabel.textAlignment = .center
        addItemLabel.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(cameraButton)
        container.addSubview(cameraLabel)
        container.addSubview(addItemButton)
        container.addSubview(addItemLabel)
        
        NSLayoutConstraint.activate([
            cameraButton.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 60),
            cameraButton.topAnchor.constraint(equalTo: container.topAnchor),
            cameraButton.widthAnchor.constraint(equalToConstant: 60),
            cameraButton.heightAnchor.constraint(equalToConstant: 60),
            
            cameraLabel.topAnchor.constraint(equalTo: cameraButton.bottomAnchor, constant: 8),
            cameraLabel.centerXAnchor.constraint(equalTo: cameraButton.centerXAnchor),
            cameraLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            
            addItemButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -60),
            addItemButton.topAnchor.constraint(equalTo: container.topAnchor),
            addItemButton.widthAnchor.constraint(equalToConstant: 60),
            addItemButton.heightAnchor.constraint(equalToConstant: 60),
            
            addItemLabel.topAnchor.constraint(equalTo: addItemButton.bottomAnchor, constant: 8),
            addItemLabel.centerXAnchor.constraint(equalTo: addItemButton.centerXAnchor),
            
            container.heightAnchor.constraint(equalToConstant: 90)
        ])
        
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
    
    private func setupConstraints() {
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
            
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -100), // Add extra bottom padding
            
            commentsTextView.heightAnchor.constraint(equalToConstant: 100),
            exitButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
        
        private func setupActions() {
            issueDropdownButton.addTarget(self, action: #selector(issueDropdownTapped), for: .touchUpInside)
            importanceToggleButton.addTarget(self, action: #selector(importanceToggleTapped), for: .touchUpInside) // NEW
            cameraButton.addTarget(self, action: #selector(cameraTapped), for: .touchUpInside)
            addItemButton.addTarget(self, action: #selector(addItemTapped), for: .touchUpInside)
            exitButton.addTarget(self, action: #selector(exitTapped), for: .touchUpInside)
        }
        
        private func setupTextViewDelegate() {
            commentsTextView.delegate = self
        }
        
        private func setupDamageComponents() {
            damageHierarchy = createDamageHierarchy()
        }
        
        // MARK: - Helper Methods
        private func createLabeledField(labelText: String, field: UIView) -> UIView {
            let container = UIView()
            let label = UILabel()
            label.text = labelText
            label.font = UIFont.boldSystemFont(ofSize: 16)
            label.translatesAutoresizingMaskIntoConstraints = false
            
            container.addSubview(label)
            container.addSubview(field)
            
            NSLayoutConstraint.activate([
                label.topAnchor.constraint(equalTo: container.topAnchor),
                label.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                label.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                
                field.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 8),
                field.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                field.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                field.bottomAnchor.constraint(equalTo: container.bottomAnchor)
            ])
            
            return container
        }
        
    private func setupKeyboardHandling() {
        // Add keyboard observers
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
        
        // Add tap gesture to dismiss keyboard
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)
        
        // Set up text field delegates for tracking active field
        primaryLocationTextField.delegate = self
        secondaryLocationTextField.delegate = self
    }

    // Add these keyboard handling methods
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
            } else if let activeTextView = self.activeTextView {
                self.scrollToField(activeTextView)
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

    // Add deinit to remove observers
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
        private func updateSelectedIssueDisplay() {
            if selectedComponents.isEmpty {
                selectedIssueLabel.text = "No issue selected"
                selectedIssueLabel.textColor = .systemGray
                issueDropdownButton.setTitle("Select Issue", for: .normal)
            } else {
                let componentNames = selectedComponents.map { $0.name }
                selectedIssueLabel.text = "Selected: " + componentNames.joined(separator: ", ")
                selectedIssueLabel.textColor = .label
                issueDropdownButton.setTitle("\(selectedComponents.count) issue(s) selected", for: .normal)
            }
        }
        
        private func resetDamageComponentsSelection() {
            func resetComponent(_ component: DamageComponent) {
                component.isSelected = false
                component.children.forEach { resetComponent($0) }
            }
            
            damageHierarchy.forEach { resetComponent($0) }
        }
        
        private func clearForm() {
            primaryLocationTextField.text = ""
            secondaryLocationTextField.text = ""
            
            selectedComponents = []
            resetDamageComponentsSelection()
            updateSelectedIssueDisplay()
            
            // NEW: Reset importance to default
            currentImportance = "Monitor"
            updateImportanceToggleDisplay()
            
            commentsTextView.text = "Enter comments here..."
            commentsTextView.textColor = UIColor.lightGray
            
            photoURL = nil
            let configuration = UIImage.SymbolConfiguration(pointSize: 24, weight: .medium)
            let cameraImage = UIImage(systemName: "camera.fill", withConfiguration: configuration)
            cameraButton.setImage(cameraImage, for: .normal)
            
            primaryLocationTextField.becomeFirstResponder()
        }
        
        private func hasFormData() -> Bool {
            let hasPrimaryLocation = !(primaryLocationTextField.text?.isEmpty ?? true)
            let hasSecondaryLocation = !(secondaryLocationTextField.text?.isEmpty ?? true)
            let hasIssues = !selectedComponents.isEmpty
            let hasComments = commentsTextView.textColor != UIColor.lightGray && !commentsTextView.text.isEmpty
            let hasPhoto = photoURL != nil
            
            return hasPrimaryLocation || hasSecondaryLocation || hasIssues || hasComments || hasPhoto
        }
        
        private func createDamageHierarchy() -> [DamageComponent] {
            // Same hierarchy creation as before
            let uprightFront = DamageComponent(name: "Front", children: [
                DamageComponent(name: "Damage"),
                DamageComponent(name: "Twisted")
            ])
            let uprightRear = DamageComponent(name: "Rear", children: [
                DamageComponent(name: "Damage"),
                DamageComponent(name: "Twisted")
            ])
            let uprightAlignment = DamageComponent(name: "Alignment", children: [
                DamageComponent(name: "Out of alignment"),
                DamageComponent(name: "Out of vertical plumb")
            ])
            let upright = DamageComponent(name: "Upright", children: [uprightFront, uprightRear, uprightAlignment])

            let beam = DamageComponent(name: "Beam", children: [
                DamageComponent(name: "Front damage"),
                DamageComponent(name: "Rear damage"),
                DamageComponent(name: "Front bowed"),
                DamageComponent(name: "Rear bowed")
            ])

            let wireDeck = DamageComponent(name: "Wire Deck", children: [
                DamageComponent(name: "Missing"),
                DamageComponent(name: "Damaged"),
                DamageComponent(name: "Out of position")
            ])

            let basePlate = DamageComponent(name: "Base Plate", children: [
                DamageComponent(name: "Floor damaged"),
                DamageComponent(name: "Twisted"),
                DamageComponent(name: "Damaged")
            ])

            let anchors = DamageComponent(name: "Anchors", children: [
                DamageComponent(name: "Missing anchors or bolts"),
                DamageComponent(name: "Damaged or bent"),
                DamageComponent(name: "Torqued to 35lbs")
            ])

            let bracingDamage = DamageComponent(name: "Bracing Damage", children: [
                DamageComponent(name: "Horizontal"),
                DamageComponent(name: "Diagonal")
            ])

            let postProtector = DamageComponent(name: "Post Protector", children: [
                DamageComponent(name: "Missing"),
                DamageComponent(name: "Damaged"),
                DamageComponent(name: "Repair required")
            ])

            let aisleGuarding = DamageComponent(name: "Aisle Guarding", children: [
                DamageComponent(name: "Missing"),
                DamageComponent(name: "Damaged"),
                DamageComponent(name: "Repair required")
            ])

            return [upright, beam, wireDeck, basePlate, anchors, bracingDamage, postProtector, aisleGuarding]
        }
        
        // MARK: - Actions
        @objc private func issueDropdownTapped() {
            let damageSelectionVC = DamageComponentSelectionViewController()
            damageSelectionVC.damageComponents = damageHierarchy
            damageSelectionVC.selectedComponents = selectedComponents
            damageSelectionVC.delegate = self
            
            let navigationController = UINavigationController(rootViewController: damageSelectionVC)
            present(navigationController, animated: true)
        }
        
        // NEW: Importance toggle action
        @objc private func importanceToggleTapped() {
            currentImportance = (currentImportance == "Monitor") ? "Needs immediate attention" : "Monitor"
            updateImportanceToggleDisplay()
        }
        
        @objc private func cameraTapped() {
            guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
                showAlert(message: "Camera is not available")
                return
            }
            
            let imagePicker = UIImagePickerController()
            imagePicker.sourceType = .camera
            imagePicker.delegate = self
            present(imagePicker, animated: true)
        }
        
        @objc private func addItemTapped() {
            guard validateForm() else { return }
            
            saveCurrentItem()
            clearForm()
            showTemporaryMessage("Item added successfully!")
        }
        
        @objc private func exitTapped() {
            if hasFormData() {
                let alert = UIAlertController(
                    title: "Save Current Item?",
                    message: "You have unsaved data. Would you like to save this item before exiting?",
                    preferredStyle: .alert
                )
                
                alert.addAction(UIAlertAction(title: "Save & Exit", style: .default) { [weak self] _ in
                    guard let self = self else { return }
                    if self.validateForm() {
                        self.saveCurrentItem()
                    }
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
        
        // MARK: - Helper Methods
        private func saveCurrentItem() {
            let context = CoreDataManager.shared.context
            let inspectionItem = InspectionItem(context: context)
            
            inspectionItem.id = UUID()
            inspectionItem.location = primaryLocationTextField.text ?? ""
            inspectionItem.bayNumber = secondaryLocationTextField.text ?? ""
            inspectionItem.importance = currentImportance // NEW: Save importance
            
            if commentsTextView.textColor != UIColor.lightGray {
                inspectionItem.comments = commentsTextView.text
            }
            
            if let photoURL = self.photoURL {
                inspectionItem.photoURL = photoURL.path
            }
            
            updateInspectionItemWithSelectedComponents(inspectionItem)
            
            if let viewModel = viewModel {
                inspectionItem.inspection = viewModel.inspection
                viewModel.saveInspectionItem(item: inspectionItem)
            }
        }
    
    private func finishInspection() {
            if let viewModel = viewModel {
                viewModel.saveCurrentInspection()
            }
            navigationController?.popViewController(animated: true)
        }
        
        private func showTemporaryMessage(_ message: String) {
            let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            present(alert, animated: true)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                alert.dismiss(animated: true)
            }
        }
    
    private func cleanupUnusedPhoto(_ photoURL: URL) {
        do {
            try FileManager.default.removeItem(at: photoURL)
        } catch {
            print("Failed to cleanup photo: \(error)")
        }
    }
    
    
    // MARK: - UIImagePickerControllerDelegate
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let image = info[.originalImage] as? UIImage {
            saveImageToDocuments(image: image)
        }
        picker.dismiss(animated: true)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
    
    private func saveImageToDocuments(image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        let fileName = "\(UUID().uuidString).jpg"
        let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(fileName)
        
        do {
            try data.write(to: fileURL)
            self.photoURL = fileURL
            
            // Update camera button to show photo was taken
            let configuration = UIImage.SymbolConfiguration(pointSize: 24, weight: .medium)
            let checkmarkImage = UIImage(systemName: "checkmark.circle.fill", withConfiguration: configuration)
            cameraButton.setImage(checkmarkImage, for: .normal)
        } catch {
            print("Error saving image: \(error)")
            showAlert(message: "Failed to save photo")
        }
    }
    
    private func updateInspectionItemWithSelectedComponents(_ item: InspectionItem) {
        for component in selectedComponents {
            switch component.name {
            case "Upright":
                item.upright = true
            case "Front" where component.parent?.name == "Upright":
                // When "Front" is selected under Upright
                break // This case handles the intermediate level
            case "Rear" where component.parent?.name == "Upright":
                // When "Rear" is selected under Upright
                break // This case handles the intermediate level
            case "Alignment" where component.parent?.name == "Upright":
                // When "Alignment" is selected under Upright
                break // This case handles the intermediate level
            case "Damage" where component.parent?.name == "Front" && component.parent?.parent?.name == "Upright":
                item.uprightFrontDamage = true
            case "Twisted" where component.parent?.name == "Front" && component.parent?.parent?.name == "Upright":
                item.uprightFrontTwisted = true
            case "Damage" where component.parent?.name == "Rear" && component.parent?.parent?.name == "Upright":
                item.uprightRearDamage = true
            case "Twisted" where component.parent?.name == "Rear" && component.parent?.parent?.name == "Upright":
                item.uprightRearTwisted = true
            case "Out of alignment":
                item.uprightAlignmentOutOfAlignment = true
            case "Out of vertical plumb":
                item.uprightAlignmentOutOfVerticalPlumb = true
            case "Front damage":
                item.beamFrontDamage = true
            case "Rear damage":
                item.beamRearDamage = true
            case "Front bowed":
                item.beamFrontBowed = true
            case "Rear bowed":
                item.beamRearBowed = true
            case "Beam":
                item.beam = true
            case "Wire Deck":
                item.wireDeck = true
            case "Missing" where component.parent?.name == "Wire Deck":
                item.wireDeckMissing = true
            case "Damaged" where component.parent?.name == "Wire Deck":
                item.wireDeckDamaged = true
            case "Out of position":
                item.wireDeckOutOfPosition = true
            case "Base Plate":
                item.basePlate = true
            case "Floor damaged":
                item.basePlateFloorDamaged = true
            case "Twisted" where component.parent?.name == "Base Plate":
                item.basePlateTwisted = true
            case "Damaged" where component.parent?.name == "Base Plate":
                item.basePlateDamaged = true
            case "Anchors":
                item.anchors = true
            case "Missing anchors or bolts":
                item.anchorsMissing = true
            case "Damaged or bent":
                item.anchorsDamaged = true
            case "Torqued to 35lbs":
                item.anchorsTorqued = true
            case "Bracing Damage":
                item.bracingDamage = true
            case "Horizontal":
                item.bracingHorizontal = true
            case "Diagonal":
                item.bracingDiagonal = true
            case "Post Protector":
                item.postProtector = true
            case "Missing" where component.parent?.name == "Post Protector":
                item.postProtectorMissing = true
            case "Damaged" where component.parent?.name == "Post Protector":
                item.postProtectorDamaged = true
            case "Repair required" where component.parent?.name == "Post Protector":
                item.postProtectorRepairRequired = true
            case "Aisle Guarding":
                item.aisleGuarding = true
            case "Missing" where component.parent?.name == "Aisle Guarding":
                item.aisleGuardingMissing = true
            case "Damaged" where component.parent?.name == "Aisle Guarding":
                item.aisleGuardingDamaged = true
            case "Repair required" where component.parent?.name == "Aisle Guarding":
                item.aisleGuardingRepairRequired = true
            default:
                break
            }
        }
    }
    
    // MARK: - Validation
    private func validateForm() -> Bool {
        guard let primaryLocation = primaryLocationTextField.text, !primaryLocation.isEmpty else {
            showAlert(message: "Please fill in Primary Location (Area/Aisle)")
            primaryLocationTextField.becomeFirstResponder()
            return false
        }
        return true
    }
    
    private func showAlert(message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UITextViewDelegate
extension InspectionFormViewController: UITextViewDelegate {
    func textViewDidBeginEditing(_ textView: UITextView) {
        activeTextView = textView
        activeTextField = nil
        
        if textView.textColor == UIColor.lightGray {
            textView.text = ""
            textView.textColor = UIColor.black
        }
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        activeTextView = nil
        
        if textView.text.isEmpty {
            textView.text = "Enter comments here..."
            textView.textColor = UIColor.lightGray
        }
    }
}

// MARK: - DamageComponentSelectionDelegate
extension InspectionFormViewController: DamageComponentSelectionDelegate {
    func didSelectDamageComponents(_ components: [DamageComponent]) {
        selectedComponents = components
        updateSelectedIssueDisplay()
    }
}

// MARK: - UITextFieldDelegate (Add this extension)
extension InspectionFormViewController: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        activeTextField = textField
        activeTextView = nil
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        activeTextField = nil
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        // Move to next field or dismiss keyboard
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
