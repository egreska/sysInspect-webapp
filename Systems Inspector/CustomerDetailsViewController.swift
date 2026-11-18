//
//  CustomerDetailsViewController.swift
//  Systems Inspector
//
//  Created by Eric Greska on 5/22/25.
//
import UIKit
import CoreData

class CustomerDetailsViewController: UIViewController {
    
    private var customer: Customer
    private var inspections: [Inspection] = []
    private var itemCounts: [NSManagedObjectID: Int] = [:]
    private var isLoadingInspections = false
    private static let skeletonRowCount = 4
    private let tableView = UITableView()
    private let headerView = UIView()
    private let newInspectionButton = UIButton(type: .system)
    private var headerHeightConstraint: NSLayoutConstraint!
    private lazy var emptyStateView: EmptyStateView = {
        let view = EmptyStateView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    init(customer: Customer) {
        self.customer = customer
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupCustomerInfoHeader()

        // Only Edit Customer button in navigation bar
        let editCustomerButton = UIBarButtonItem(
            title: "Edit Customer",
            style: .plain,
            target: self,
            action: #selector(editCustomerTapped)
        )
        
        navigationItem.rightBarButtonItem = editCustomerButton

        registerForTraitChanges([
            UITraitPreferredContentSizeCategory.self,
            UITraitUserInterfaceStyle.self
        ]) { (controller: Self, _: UITraitCollection) in
            controller.setupCustomerInfoHeader()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        fetchInspections()
    }
    
    // MARK: - Edit Customer Action
    @objc private func editCustomerTapped() {
        let formVC = CustomerFormViewController(customer: customer)
        formVC.delegate = self
        let navController = UINavigationController(rootViewController: formVC)
        if let sheet = navController.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
        present(navController, animated: true)
    }

    @objc private func siteRackingTapped() {
        let form = CustomerIntake.formState(from: customer)
        let sheet = SiteRackingViewController(form: form) { [weak self] form in
            guard let self else { return }
            if CustomerIntake.update(self.customer, form: form) {
                CustomerSearchIndex.refreshFromStore()
            }
            self.setupCustomerInfoHeader()
        }
        let nav = UINavigationController(rootViewController: sheet)
        if let presentation = nav.sheetPresentationController {
            presentation.detents = [.large()]
            presentation.prefersGrabberVisible = true
        }
        present(nav, animated: true)
    }
    
    // MARK: - Add Inspection Action
    @objc private func newInspectionTouchDown() {
        HapticManager.lightImpact()
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        UIView.animate(withDuration: 0.1) {
            self.newInspectionButton.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }
    }

    @objc private func newInspectionTouchEnded() {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        UIView.animate(withDuration: 0.1) {
            self.newInspectionButton.transform = .identity
        }
    }

    @objc private func addInspectionTapped() {
        newInspectionTouchEnded()
        let inspectionFormVC = InspectionItemFormViewController(viewModel: InspectionFormViewModel(customer: customer))
        navigationController?.pushViewController(inspectionFormVC, animated: true)
    }
    
    private func setupUI() {
        title = customer.name
        view.backgroundColor = AppTheme.background
        
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.backgroundColor = AppTheme.surface
        headerView.layer.cornerRadius = AppTheme.cardCornerRadius
        headerView.clipsToBounds = true
        
        newInspectionButton.setTitle("New Inspection", for: .normal)
        newInspectionButton.backgroundColor = AppTheme.primary
        newInspectionButton.setTitleColor(AppTheme.primaryContrast, for: .normal)
        newInspectionButton.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        newInspectionButton.titleLabel?.adjustsFontForContentSizeCategory = true
        newInspectionButton.layer.cornerRadius = AppTheme.buttonCornerRadius
        newInspectionButton.layer.shadowColor = UIColor.label.cgColor
        newInspectionButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        newInspectionButton.layer.shadowOpacity = 0.1
        newInspectionButton.layer.shadowRadius = 4
        newInspectionButton.translatesAutoresizingMaskIntoConstraints = false
        newInspectionButton.addTarget(self, action: #selector(newInspectionTouchDown), for: .touchDown)
        newInspectionButton.addTarget(self, action: #selector(newInspectionTouchEnded), for: .touchUpOutside)
        newInspectionButton.addTarget(self, action: #selector(newInspectionTouchEnded), for: .touchCancel)
        newInspectionButton.addTarget(self, action: #selector(addInspectionTapped), for: .touchUpInside)
        newInspectionButton.accessibilityLabel = "New inspection"
        
        tableView.register(SubtitleCell.self, forCellReuseIdentifier: "InspectionCell")
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 60
        tableView.register(SkeletonCell.self, forCellReuseIdentifier: SkeletonCell.reuseId)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.tableFooterView = UIView()
        
        // Add all subviews to the main view
        view.addSubview(headerView)
        view.addSubview(newInspectionButton)
        view.addSubview(tableView)
        
        // Create height constraint that we can update
        headerHeightConstraint = headerView.heightAnchor.constraint(equalToConstant: 200)
        
        // Layout Constraints
        NSLayoutConstraint.activate([
            // Header view constraints
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: AppTheme.spacing16),
            headerHeightConstraint,
        ] + AppTheme.readableWidthConstraints(
            for: headerView,
            width: view.widthAnchor,
            centerX: view.centerXAnchor,
            leading: view.leadingAnchor,
            trailing: view.trailingAnchor,
            margin: AppTheme.spacing16
        ) + [
            
            // New Inspection button constraints
            newInspectionButton.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 16),
            newInspectionButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            newInspectionButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            newInspectionButton.heightAnchor.constraint(equalToConstant: 50),
            
            // Table view constraints
            tableView.topAnchor.constraint(equalTo: newInspectionButton.bottomAnchor, constant: 16),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func setupCustomerInfoHeader() {
        headerView.subviews.forEach { $0.removeFromSuperview() }

        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = AppTheme.spacing8
        stackView.alignment = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(stackView)

        let companyLabel = UILabel()
        let companyName = trimmed(customer.name) ?? "Unknown"
        companyLabel.text = companyName
        companyLabel.font = AppTheme.fontBold(.title2)
        companyLabel.adjustsFontForContentSizeCategory = true
        companyLabel.textColor = AppTheme.textPrimary
        companyLabel.numberOfLines = 0
        stackView.addArrangedSubview(companyLabel)

        if let site = trimmed(customer.site) {
            stackView.addArrangedSubview(createDetailLabel(title: "Site:", value: site))
        }
        if let contactName = trimmed(customer.contactName) {
            stackView.addArrangedSubview(createDetailLabel(title: "Contact:", value: contactName))
        }
        if let phone = trimmed(customer.phone) {
            stackView.addArrangedSubview(createDetailLabel(title: "Phone:", value: phone))
        }
        if let address = addressLine() {
            stackView.addArrangedSubview(createDetailLabel(title: "Address:", value: address))
        }

        let siteButton = UIButton(type: .system)
        siteButton.setTitle("Site racking & documents", for: .normal)
        siteButton.contentHorizontalAlignment = .left
        siteButton.titleLabel?.font = AppTheme.font(.body)
        siteButton.titleLabel?.adjustsFontForContentSizeCategory = true
        siteButton.addTarget(self, action: #selector(siteRackingTapped), for: .touchUpInside)
        siteButton.accessibilityLabel = "Site racking and documents"
        stackView.addArrangedSubview(siteButton)
        let subtitle = UILabel()
        subtitle.text = CustomerIntake.formState(from: customer).siteRackingSubtitle
        subtitle.font = AppTheme.font(.footnote)
        subtitle.adjustsFontForContentSizeCategory = true
        subtitle.textColor = AppTheme.textSecondary
        subtitle.numberOfLines = 0
        stackView.addArrangedSubview(subtitle)

        stackView.addArrangedSubview(createDetailLabel(
            title: "Inspections:",
            value: "\(inspections.count)"
        ))
        
        // Layout constraints for stack view
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: headerView.topAnchor, constant: AppTheme.spacing16),
            stackView.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: AppTheme.spacing16),
            stackView.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -AppTheme.spacing16),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: headerView.bottomAnchor, constant: -AppTheme.spacing16)
        ])
        
        // Calculate and update header height
        updateHeaderHeight()
    }

    private func updateHeaderHeight() {
        // Force layout to calculate the content size
        headerView.layoutIfNeeded()
        
        // Get the actual height needed by the stack view
        guard let stackView = headerView.subviews.first as? UIStackView else {
            headerHeightConstraint.constant = 120
            return
        }
        
        // Calculate required height based on stack view's intrinsic content size
        let stackViewHeight = stackView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize).height
        let estimatedHeight = max(120, stackViewHeight + 32) // Add padding
        
        // Update the height constraint. The first call is from viewDidLoad, before this
        // controller is in a window. Forcing layout then makes the inspections table
        // lay out off-screen (UITableViewAlertForLayoutOutsideViewHierarchy).
        headerHeightConstraint.constant = CGFloat(estimatedHeight)
        guard view.window != nil else { return }

        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
        }
    }

    private func updateInspectionCountInHeader() {
        setupCustomerInfoHeader()
    }

    private func trimmed(_ value: String?) -> String? {
        let text = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return text.isEmpty ? nil : text
    }

    /// Street, city, state, and zip on one line. Empty parts are left out.
    private func addressLine() -> String? {
        let street = trimmed(customer.address) ?? ""
        let city = trimmed(customer.city) ?? ""
        let state = trimmed(customer.state) ?? ""
        let zip = trimmed(customer.zipCode) ?? ""
        var cityState = [city, state].filter { !$0.isEmpty }.joined(separator: ", ")
        if !zip.isEmpty {
            cityState = cityState.isEmpty ? zip : "\(cityState) \(zip)"
        }
        let line = [street, cityState].filter { !$0.isEmpty }.joined(separator: ", ")
        return line.isEmpty ? nil : line
    }

    private func updateEmptyState() {
        guard inspections.isEmpty else {
            tableView.backgroundView = nil
            return
        }
        let container = UIView(frame: tableView.bounds)
        container.backgroundColor = AppTheme.background
        container.addSubview(emptyStateView)
        NSLayoutConstraint.activate([
            emptyStateView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            emptyStateView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            emptyStateView.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 32),
            emptyStateView.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -32)
        ])
        emptyStateView.configure(
            symbolNames: ["clipboard", "plus.circle"],
            symbolPointSize: 44,
            title: "No inspections yet",
            message: "Start an inspection for this customer to record issues and generate reports.",
            buttonTitle: "Start inspection",
            buttonAction: { [weak self] in self?.addInspectionTapped() }
        )
        tableView.backgroundView = container
    }
    
    private func createDetailLabel(title: String, value: String) -> UILabel {
        let label = UILabel()
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        label.translatesAutoresizingMaskIntoConstraints = false

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: AppTheme.fieldLabel(),
            .foregroundColor: AppTheme.textSecondary
        ]
        let valueAttributes: [NSAttributedString.Key: Any] = [
            .font: AppTheme.font(.body),
            .foregroundColor: AppTheme.textPrimary
        ]
        let attributedString = NSMutableAttributedString(string: title + " ", attributes: titleAttributes)
        attributedString.append(NSAttributedString(string: value, attributes: valueAttributes))
        label.attributedText = attributedString
        
        // Set content hugging and compression resistance priorities
        label.setContentHuggingPriority(.required, for: .vertical)
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        
        return label
    }
    
    private func fetchInspections() {
        guard let currentUserID = UserManager.shared.sessionUserId else {
            inspections = []
            itemCounts = [:]
            DispatchQueue.main.async {
                self.tableView.reloadData()
                self.updateInspectionCountInHeader()
                self.updateEmptyState()
            }
            return
        }
        isLoadingInspections = true
        if tableView.window != nil {
            tableView.reloadData()
        }
        
        let customer = self.customer
        let viewContext = CoreDataManager.shared.context
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let result = try await sessionInspections(for: customer, userId: currentUserID, in: viewContext)
                self.isLoadingInspections = false
                self.itemCounts = sessionInspectionItemCounts(for: result, userId: currentUserID, in: viewContext)
                self.inspections = result
                self.tableView.reloadData()
                self.updateInspectionCountInHeader()
                self.updateEmptyState()
            } catch {
                self.isLoadingInspections = false
                self.tableView.reloadData()
                self.updateInspectionCountInHeader()
                self.updateEmptyState()
            }
        }
    }
}

// MARK: - UITableViewDataSource
extension CustomerDetailsViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if isLoadingInspections && inspections.isEmpty { return Self.skeletonRowCount }
        return inspections.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if isLoadingInspections && inspections.isEmpty {
            return tableView.dequeueReusableCell(withIdentifier: SkeletonCell.reuseId, for: indexPath)
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: "InspectionCell", for: indexPath)
        let inspection = inspections[indexPath.row]

        let dateString: String
        if let inspectionDate = inspection.date {
            dateString = DateFormatters.format(inspectionDate, using: DateFormatters.mediumDateTime)
        } else {
            dateString = "Unknown date"
        }

        cell.textLabel?.text = "Inspection on \(dateString)"

        let itemCount = itemCounts[inspection.objectID] ?? 0
        cell.detailTextLabel?.text = "\(itemCount) item\(itemCount == 1 ? "" : "s")"

        cell.accessoryType = .disclosureIndicator

        return cell
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return inspections.isEmpty ? "No Inspections" : "Inspection History"
    }
}

// MARK: - UITableViewDelegate
extension CustomerDetailsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard !isLoadingInspections, indexPath.row < inspections.count else {
            tableView.deselectRow(at: indexPath, animated: true)
            return
        }
        let inspection = inspections[indexPath.row]
        
        let inspectionDetailsVC = InspectionDetailsViewController(inspection: inspection)
        navigationController?.pushViewController(inspectionDetailsVC, animated: true)
        
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard !isLoadingInspections, indexPath.row < inspections.count else { return nil }
        let inspection = inspections[indexPath.row]
        
        return UIContextMenuConfiguration(identifier: indexPath as NSIndexPath, previewProvider: nil) { [weak self] _ in
            guard let self = self else { return UIMenu() }
            
            let newInspection = UIAction(title: "New inspection", image: UIImage(systemName: "plus.circle")) { _ in
                self.addInspectionTapped()
            }
            
            let edit = UIAction(title: "Edit", image: UIImage(systemName: "pencil")) { _ in
                let inspectionDetailsVC = InspectionDetailsViewController(inspection: inspection)
                self.navigationController?.pushViewController(inspectionDetailsVC, animated: true)
            }
            
            let delete = UIAction(title: "Delete", image: UIImage(systemName: "trash"), attributes: .destructive) { _ in
                let alert = UIAlertController(
                    title: "Delete Inspection",
                    message: "Are you sure you want to delete this inspection? This action cannot be undone.",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
                alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { _ in
                    CoreDataManager.shared.deleteObject(inspection)
                    self.inspections.remove(at: indexPath.row)
                    tableView.deleteRows(at: [indexPath], with: .fade)
                    self.updateInspectionCountInHeader()
                    self.updateEmptyState()
                })
                self.present(alert, animated: true)
            }
            
            return UIMenu(children: [newInspection, edit, delete])
        }
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let inspectionToDelete = inspections[indexPath.row]
            
            let alert = UIAlertController(
                title: "Delete Inspection",
                message: "Are you sure you want to delete this inspection? This action cannot be undone.",
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            
            alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
                guard let self = self else { return }
                
                // Use CoreDataManager.deleteObject for CloudKit sync
                CoreDataManager.shared.deleteObject(inspectionToDelete)
                
                self.inspections.remove(at: indexPath.row)
                tableView.deleteRows(at: [indexPath], with: .fade)
                self.updateInspectionCountInHeader()
                self.updateEmptyState()
            })
            
            present(alert, animated: true)
        }
    }
}

// MARK: - CustomerFormDelegate
extension CustomerDetailsViewController: CustomerFormDelegate {
    func didSaveCustomer(_ customer: Customer, isNew: Bool) {
        self.customer = customer
        title = customer.name
        setupCustomerInfoHeader()
    }
}

// MARK: - InspectionDetailsViewController
class InspectionDetailsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private let inspection: Inspection
    private let tableView = UITableView()
    private var inspectionItems: [InspectionItem] = []
    private var isEditingMode = false
    
    init(inspection: Inspection) {
        self.inspection = inspection
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadInspectionItems()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadInspectionItems() // Refresh data when returning from edit
    }
    
    // Update the setupUI method in InspectionDetailsViewController

    private func setupUI() {
        title = "Inspection Details"
        view.backgroundColor = AppTheme.background
        
        // Replace multiple buttons with single actions button
        let actionsItem = UIBarButtonItem(
            image: UIImage(systemName: "ellipsis.circle"),
            style: .plain,
            target: self,
            action: #selector(showActionSheet)
        )
        actionsItem.accessibilityLabel = "Inspection actions"
        navigationItem.rightBarButtonItem = actionsItem
        
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(SubtitleCell.self, forCellReuseIdentifier: "ItemCell")
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 60
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.tableFooterView = UIView()
        
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    // NEW: Add this method
    @objc private func showActionSheet() {
        let actionSheet = UIAlertController(title: "Inspection Actions", message: nil, preferredStyle: .actionSheet)
        
        // Resume Inspection action
        actionSheet.addAction(UIAlertAction(title: "Resume Inspection", style: .default, handler: { [weak self] _ in
            self?.resumeInspection()
        }))
        
        // Edit Items action
        let editTitle = isEditingMode ? "Done Editing" : "Edit Items"
        actionSheet.addAction(UIAlertAction(title: editTitle, style: .default, handler: { [weak self] _ in
            self?.toggleEditMode()
        }))
        
        // Cancel action
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // iPad support
        if let popoverController = actionSheet.popoverPresentationController {
            popoverController.barButtonItem = navigationItem.rightBarButtonItem
        }
        
        present(actionSheet, animated: true)
    }

    
    @objc private func resumeInspection() {
        let inspectionFormVC = InspectionItemFormViewController(viewModel: InspectionFormViewModel(existingInspection: inspection))
        navigationController?.pushViewController(inspectionFormVC, animated: true)
    }

    private func loadInspectionItems() {
        guard let currentUserID = UserManager.shared.sessionUserId else {
            inspectionItems = []
            DispatchQueue.main.async { self.tableView.reloadData() }
            return
        }
        let inspection = self.inspection
        let viewContext = CoreDataManager.shared.context
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let result = try await sessionInspectionItems(for: inspection, userId: currentUserID, in: viewContext)
                self.inspectionItems = RecordedOrder.sorted(result) { $0.sequenceNumber }
                self.tableView.reloadData()
            } catch {
                self.tableView.reloadData()
            }
        }
    }
    
    @objc private func toggleEditMode() {
        isEditingMode.toggle()
        
        if isEditingMode {
            // Updated to use the ellipsis button's image for "Done Editing"
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                barButtonSystemItem: .done,
                target: self,
                action: #selector(showActionSheet) // Still open action sheet
            )
        } else {
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                image: UIImage(systemName: "ellipsis.circle"),
                style: .plain,
                target: self,
                action: #selector(showActionSheet)
            )
        }
        
        tableView.setEditing(isEditingMode, animated: true)
    }
    
    // MARK: - UITableViewDataSource
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return inspectionItems.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ItemCell", for: indexPath)
        let item = inspectionItems[indexPath.row]
        
        let primaryLocation = item.location ?? "N/A"
        let secondaryLocation = item.bayNumber ?? "N/A"
        
        // Include importance indicator in the title
        let importance = Importance(stored: item.importance)
        let importanceIcon = importance.isImmediate ? "🔺" : "👁"
        
        var title = "\(importanceIcon) \(primaryLocation) - \(secondaryLocation)"
        let photoCount = item.photoCount
        if photoCount > 1 {
            title += "  (\(photoCount) photos)"
        } else if photoCount == 1 {
            title += "  (photo)"
        }
        cell.textLabel?.text = title
        
        let issueStrings = Issue.labels(from: item.recordedIssues())
        cell.detailTextLabel?.text = issueStrings.isEmpty ? "No issues" : issueStrings.joined(separator: "\n")
        cell.detailTextLabel?.numberOfLines = 0
        
        cell.accessoryType = .disclosureIndicator
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Inspection on \(DateFormatters.format(inspection.date ?? Date(), using: DateFormatters.long))"
    }
    
    // MARK: - UITableViewDelegate
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = inspectionItems[indexPath.row]
        
        if isEditingMode {
            // Open edit form
            editInspectionItem(item)
        } else {
            // Show detail view
            let detailVC = InspectionItemDetailViewController(inspectionItem: item)
            navigationController?.pushViewController(detailVC, animated: true)
        }
    }
    
    // MARK: - Editing Support
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return isEditingMode
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let itemToDelete = inspectionItems[indexPath.row]
            
            let alert = UIAlertController(
                title: "Delete Item",
                message: "Are you sure you want to delete this inspection item?",
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            
            alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
                guard let self = self else { return }
                
                CoreDataManager.shared.deleteObject(itemToDelete)
                
                // Remove from array and update table
                self.inspectionItems.remove(at: indexPath.row)
                tableView.deleteRows(at: [indexPath], with: .fade)
            })
            
            present(alert, animated: true)
        }
    }
    
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .delete
    }
    
    // MARK: - Helper Methods
    private func editInspectionItem(_ item: InspectionItem) {
        let editVC = InspectionItemFormViewController(inspectionItem: item)
        editVC.delegate = self
        let navController = UINavigationController(rootViewController: editVC)
        present(navController, animated: true)
    }
}

// MARK: - InspectionItemFormDelegate
extension CustomerDetailsViewController: InspectionItemFormDelegate {
    func didSaveInspectionItem() {
            // Refresh the display with updated data
            DispatchQueue.main.async {
                // FIXED: Call setupUI instead of loadInspectionItems
                self.setupUI() // This will update the title and content
            }
        }
    }

// MARK: - InspectionItemDetailViewController
class InspectionItemDetailViewController: UIViewController {
    private let inspectionItem: InspectionItem
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let detailStack = UIStackView()
    private var didInstallChrome = false
    
    init(inspectionItem: InspectionItem) {
        self.inspectionItem = inspectionItem
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        showItem()
    }

    private func installChrome() {
        view.backgroundColor = AppTheme.background
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Edit",
            style: .plain,
            target: self,
            action: #selector(editButtonTapped)
        )

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        detailStack.axis = .vertical
        detailStack.spacing = 16
        detailStack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(detailStack)

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

            detailStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            detailStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            detailStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            detailStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16)
        ])
        didInstallChrome = true
    }

    private func showItem() {
        if !didInstallChrome {
            installChrome()
        }
        let primaryLocation = inspectionItem.location ?? "N/A"
        let secondaryLocation = inspectionItem.bayNumber ?? "N/A"
        title = "\(primaryLocation) - \(secondaryLocation)"
        detailStack.arrangedSubviews.forEach {
            detailStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        // Add inspection details with updated labels
        addDetailLabel(to: detailStack, title: "Primary Location (Area/Aisle)", value: inspectionItem.location ?? "N/A")
        addDetailLabel(to: detailStack, title: "Secondary Location (Bay/Level)", value: inspectionItem.bayNumber ?? "N/A")
        addImportanceRow(to: detailStack, importance: Importance(stored: inspectionItem.importance))

        addSectionHeader(to: detailStack, title: "Issues")
            
        let issueStrings = Issue.labels(from: inspectionItem.recordedIssues())
        if issueStrings.isEmpty {
            let noIssuesLabel = UILabel()
            noIssuesLabel.text = "No issues recorded"
            noIssuesLabel.font = AppTheme.font(.body)
            noIssuesLabel.adjustsFontForContentSizeCategory = true
            noIssuesLabel.textColor = AppTheme.textSecondary
            detailStack.addArrangedSubview(noIssuesLabel)
        } else {
            for issueString in issueStrings {
                let issueLabel = UILabel()
                issueLabel.text = issueString
                issueLabel.font = AppTheme.font(.body)
                issueLabel.adjustsFontForContentSizeCategory = true
                issueLabel.textColor = AppTheme.textPrimary
                issueLabel.numberOfLines = 0
                detailStack.addArrangedSubview(issueLabel)
            }
        }

        if let comments = inspectionItem.comments, !comments.isEmpty {
            addSectionHeader(to: detailStack, title: "Comments")
            
            let commentsLabel = UILabel()
            commentsLabel.text = comments
            commentsLabel.numberOfLines = 0
            commentsLabel.font = AppTheme.font(.body)
            commentsLabel.adjustsFontForContentSizeCategory = true
            commentsLabel.textColor = AppTheme.textPrimary
            
            detailStack.addArrangedSubview(commentsLabel)
        }

        let photoIndexes = inspectionItem.photoIndexes()
        if !photoIndexes.isEmpty {
            addSectionHeader(to: detailStack, title: photoIndexes.count == 1 ? "Photo" : "Photos")
            let location = inspectionItem.location ?? "inspection item"
            let pixels = detailPhotoPixelSize()
            for (position, index) in photoIndexes.enumerated() {
                let imageView = UIImageView()
                imageView.contentMode = .scaleAspectFit
                imageView.layer.cornerRadius = 12
                imageView.clipsToBounds = true
                imageView.backgroundColor = AppTheme.surface
                imageView.translatesAutoresizingMaskIntoConstraints = false
                imageView.heightAnchor.constraint(equalToConstant: 200).isActive = true
                imageView.isAccessibilityElement = true
                imageView.accessibilityLabel = "Photo \(position + 1) of \(photoIndexes.count), \(location)"
                detailStack.addArrangedSubview(imageView)
                inspectionItem.getPhotoThumbnail(at: index, maxDimension: pixels) { [weak imageView] image in
                    imageView?.image = image
                }
            }
        }
    }

    /// Longer side of the 200-point photo view, in pixels.
    private func detailPhotoPixelSize() -> CGFloat {
        let scale = max(traitCollection.displayScale, 1)
        let width = view.bounds.width > 32 ? view.bounds.width - 32 : 343
        return max(width, 200) * scale
    }
    
    @objc private func editButtonTapped() {
        let editVC = InspectionItemFormViewController(inspectionItem: inspectionItem)
        editVC.delegate = self
        let navController = UINavigationController(rootViewController: editVC)
        present(navController, animated: true)
    }
    
    private func addDetailLabel(to stackView: UIStackView, title: String, value: String) {
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .preferredFont(forTextStyle: .subheadline)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textColor = .secondaryLabel
        titleLabel.numberOfLines = 0

        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = .preferredFont(forTextStyle: .body)
        valueLabel.adjustsFontForContentSizeCategory = true
        valueLabel.numberOfLines = 0

        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(valueLabel)
    }
    
    private func addSectionHeader(to stackView: UIStackView, title: String) {
        let separator = UIView()
        separator.backgroundColor = AppTheme.separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.heightAnchor.constraint(equalToConstant: 1).isActive = true
        
        let headerLabel = UILabel()
        headerLabel.text = title
        headerLabel.font = AppTheme.fontBold(.headline)
        headerLabel.adjustsFontForContentSizeCategory = true
        headerLabel.textColor = AppTheme.textPrimary
        headerLabel.accessibilityTraits = .header
        
        stackView.addArrangedSubview(UIView()) // Add some space
        stackView.addArrangedSubview(separator)
        stackView.addArrangedSubview(headerLabel)
    }
    
    private func addImportanceRow(to stackView: UIStackView, importance: Importance) {
        let titleLabel = UILabel()
        titleLabel.text = "Importance"
        titleLabel.font = .preferredFont(forTextStyle: .subheadline)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textColor = .secondaryLabel
        titleLabel.numberOfLines = 0

        let symbolName = importance.isImmediate ? "exclamationmark.triangle.fill" : "eye.fill"
        let icon = UIImageView(image: UIImage(systemName: symbolName))
        icon.tintColor = importance.isImmediate ? AppTheme.attention : AppTheme.monitor
        icon.setContentHuggingPriority(.required, for: .horizontal)
        icon.setContentCompressionResistancePriority(.required, for: .horizontal)

        let phrase = UILabel()
        phrase.text = importance.phrase
        phrase.font = AppTheme.font(.body)
        phrase.adjustsFontForContentSizeCategory = true
        phrase.textColor = importance.isImmediate ? AppTheme.attention : AppTheme.textPrimary
        phrase.numberOfLines = 0

        let row = UIStackView(arrangedSubviews: [icon, phrase])
        row.axis = .horizontal
        row.spacing = 8
        row.alignment = .center

        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(row)
    }
}

extension InspectionItemDetailViewController: InspectionItemFormDelegate {
    func didSaveInspectionItem() {
        showItem()
    }
}

extension InspectionDetailsViewController: InspectionItemFormDelegate {
    func didSaveInspectionItem() {
        loadInspectionItems()
    }
}

