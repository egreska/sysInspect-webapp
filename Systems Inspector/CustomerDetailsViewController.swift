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
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        fetchInspections()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startPulsingAnimationIfAllowed()
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
        let sheet = SiteRackingViewController(
            siteRacking: form.siteRacking,
            siteDocuments: form.siteDocuments
        ) { [weak self] racking, docs in
            guard let self else { return }
            var updated = CustomerIntake.formState(from: self.customer)
            updated.siteRacking = racking
            updated.siteDocuments = docs
            _ = CustomerIntake.update(self.customer, form: updated)
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
    @objc private func addInspectionTapped() {
        newInspectionButton.layer.removeAnimation(forKey: "pulsing")
        
        if !UIAccessibility.isReduceMotionEnabled {
            UIView.animate(withDuration: 0.1, animations: {
                self.newInspectionButton.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            }) { _ in
                UIView.animate(withDuration: 0.1, animations: {
                    self.newInspectionButton.transform = CGAffineTransform.identity
                }) { _ in
                    self.startPulsingAnimationIfAllowed()
                }
            }
        } else {
            startPulsingAnimationIfAllowed()
        }
        
        // Navigate to inspection form
        let inspectionFormVC = InspectionItemFormViewController(viewModel: InspectionFormViewModel(customer: customer))
        navigationController?.pushViewController(inspectionFormVC, animated: true)
    }
    
    // MARK: - Pulsing Animation (respects Reduce Motion)
    private func startPulsingAnimationIfAllowed() {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        let pulseAnimation = CABasicAnimation(keyPath: "transform.scale")
        pulseAnimation.duration = 1.5
        pulseAnimation.fromValue = 1.0
        pulseAnimation.toValue = 1.05
        pulseAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
        pulseAnimation.autoreverses = true
        pulseAnimation.repeatCount = .infinity
        newInspectionButton.layer.add(pulseAnimation, forKey: "pulsing")
    }
    
    private func setupUI() {
        title = customer.name
        view.backgroundColor = AppTheme.background
        
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.backgroundColor = AppTheme.surface
        
        newInspectionButton.setTitle("New Inspection", for: .normal)
        newInspectionButton.backgroundColor = AppTheme.success
        newInspectionButton.setTitleColor(AppTheme.primaryContrast, for: .normal)
        newInspectionButton.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        newInspectionButton.titleLabel?.adjustsFontForContentSizeCategory = true
        newInspectionButton.layer.cornerRadius = 12
        newInspectionButton.layer.shadowColor = UIColor.label.cgColor
        newInspectionButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        newInspectionButton.layer.shadowOpacity = 0.1
        newInspectionButton.layer.shadowRadius = 4
        newInspectionButton.translatesAutoresizingMaskIntoConstraints = false
        newInspectionButton.addTarget(self, action: #selector(addInspectionTapped), for: .touchUpInside)
        newInspectionButton.accessibilityLabel = "New inspection"
        
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "InspectionCell")
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
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerHeightConstraint,
            
            // New Inspection button constraints
            newInspectionButton.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 16),
            newInspectionButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            newInspectionButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            newInspectionButton.heightAnchor.constraint(equalToConstant: 50),
            
            // Table view constraints
            tableView.topAnchor.constraint(equalTo: newInspectionButton.bottomAnchor, constant: 16),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func setupCustomerInfoHeader() {
        // Clear existing subviews
        headerView.subviews.forEach { $0.removeFromSuperview() }
        
        // Create a stack view for better layout management
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 8
        stackView.alignment = .leading
        stackView.distribution = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        headerView.addSubview(stackView)
        
        // Create labels for all customer details in the specified order
        // Company Name (required field, always show)
        stackView.addArrangedSubview(createDetailLabel(title: "Company:", value: customer.name ?? "Unknown"))
        
        // Optional fields - only add if they have values
        if let site = customer.site, !site.isEmpty {
            stackView.addArrangedSubview(createDetailLabel(title: "Site:", value: site))
        }
        
        if let contactName = customer.contactName, !contactName.isEmpty {
            stackView.addArrangedSubview(createDetailLabel(title: "Contact:", value: contactName))
        }
        
        if let phone = customer.phone, !phone.isEmpty {
            stackView.addArrangedSubview(createDetailLabel(title: "Phone:", value: phone))
        }
        
        if let address = customer.address, !address.isEmpty {
            stackView.addArrangedSubview(createDetailLabel(title: "Address:", value: address))
        }
        
        if let city = customer.city, !city.isEmpty {
            stackView.addArrangedSubview(createDetailLabel(title: "City:", value: city))
        }
        
        if let state = customer.state, !state.isEmpty {
            stackView.addArrangedSubview(createDetailLabel(title: "State:", value: state))
        }
        
        if let zipCode = customer.zipCode, !zipCode.isEmpty {
            stackView.addArrangedSubview(createDetailLabel(title: "Zip:", value: zipCode))
        }

        let siteButton = UIButton(type: .system)
        siteButton.setTitle("Site racking & documents", for: .normal)
        siteButton.contentHorizontalAlignment = .left
        siteButton.titleLabel?.font = AppTheme.font(.body)
        siteButton.addTarget(self, action: #selector(siteRackingTapped), for: .touchUpInside)
        siteButton.accessibilityLabel = "Site racking and documents"
        stackView.addArrangedSubview(siteButton)
        let subtitle = UILabel()
        subtitle.text = CustomerIntake.formState(from: customer).siteRackingSubtitle
        subtitle.font = AppTheme.font(.footnote)
        subtitle.textColor = AppTheme.textSecondary
        subtitle.numberOfLines = 0
        stackView.addArrangedSubview(subtitle)
        
        // Always show these fields
        stackView.addArrangedSubview(createDetailLabel(
            title: "Added:",
            value: DateFormatters.format(customer.createdDate ?? Date(), using: DateFormatters.medium)
        ))
        
        stackView.addArrangedSubview(createDetailLabel(
            title: "Inspections:",
            value: "\(inspections.count)"
        ))
        
        // Layout constraints for stack view
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: headerView.bottomAnchor, constant: -16)
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
        
        // Update the height constraint
        headerHeightConstraint.constant = CGFloat(estimatedHeight)
        
        // Animate the change
        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
        }
    }

    private func updateInspectionCountInHeader() {
        // Since we're using a stack view now, we need to find and update the inspection count label
        guard let stackView = headerView.subviews.first as? UIStackView else { return }
        
        // Find the last arranged subview (should be the inspection count label)
        if let lastLabel = stackView.arrangedSubviews.last as? UILabel {
            // Create a new label with updated count
            let updatedLabel = createDetailLabel(
                title: "Inspections:",
                value: "\(inspections.count)"
            )
            
            // Remove the old label and add the new one
            stackView.removeArrangedSubview(lastLabel)
            lastLabel.removeFromSuperview()
            stackView.addArrangedSubview(updatedLabel)
        }
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
        label.translatesAutoresizingMaskIntoConstraints = false
        
        let attributedString = NSMutableAttributedString()
        
        // Title (bold)
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 16),
            .foregroundColor: UIColor.label
        ]
        attributedString.append(NSAttributedString(string: title + " ", attributes: titleAttributes))
        
        // Value (regular)
        let valueAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 16),
            .foregroundColor: UIColor.label
        ]
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
        
        let customerID = customer.objectID
        
        CoreDataManager.shared.performBackgroundTask { [weak self] context in
            guard let self = self else { return }
            do {
                guard let bgCustomer = try? context.existingObject(with: customerID) else {
                    DispatchQueue.main.async {
                        self.isLoadingInspections = false
                        self.tableView.reloadData()
                        self.updateInspectionCountInHeader()
                        self.updateEmptyState()
                    }
                    return
                }
                let req: NSFetchRequest<Inspection> = Inspection.fetchRequest()
                req.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                    NSPredicate(format: "customer == %@", bgCustomer),
                    NSPredicate(format: "userId == %@", currentUserID as CVarArg)
                ])
                req.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
                let result = try context.fetch(req)
                let objectIDs = result.map(\.objectID)
                DispatchQueue.main.async {
                    let mainContext = CoreDataManager.shared.context
                    let mainResult = objectIDs.compactMap { try? mainContext.existingObject(with: $0) as? Inspection }
                    self.isLoadingInspections = false
                    self.inspections = mainResult
                    self.tableView.reloadData()
                    self.updateInspectionCountInHeader()
                    self.updateEmptyState()
                }
            } catch {
                DispatchQueue.main.async {
                    self.isLoadingInspections = false
                    self.tableView.reloadData()
                    self.updateInspectionCountInHeader()
                    self.updateEmptyState()
                }
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

        let itemCount = inspection.items?.count ?? 0
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
                alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
                    guard let self = self else { return }
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
class InspectionDetailsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UITableViewDataSourcePrefetching {
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
        view.backgroundColor = .white
        
        // Replace multiple buttons with single actions button
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "ellipsis.circle"),
            style: .plain,
            target: self,
            action: #selector(showActionSheet)
        )
        
        tableView.dataSource = self
        tableView.delegate = self
        tableView.prefetchDataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "ItemCell")
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
        let inspectionID = inspection.objectID
        CoreDataManager.shared.performBackgroundTask { [weak self] context in
            guard let self = self else { return }
            do {
                guard let bgInspection = try? context.existingObject(with: inspectionID) else {
                    DispatchQueue.main.async { self.tableView.reloadData() }
                    return
                }
                let req: NSFetchRequest<InspectionItem> = InspectionItem.fetchRequest()
                req.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                    NSPredicate(format: "inspection == %@", bgInspection),
                    NSPredicate(format: "userId == %@", currentUserID as CVarArg)
                ])
                let result = try context.fetch(req)
                let sorted = result.sorted { item1, item2 in
                    let location1 = item1.location ?? ""
                    let location2 = item2.location ?? ""
                    if location1 == location2 {
                        return (item1.bayNumber ?? "") < (item2.bayNumber ?? "")
                    }
                    return location1 < location2
                }
                let objectIDs = sorted.map(\.objectID)
                DispatchQueue.main.async {
                    let mainContext = CoreDataManager.shared.context
                    self.inspectionItems = objectIDs.compactMap { try? mainContext.existingObject(with: $0) as? InspectionItem }
                    self.tableView.reloadData()
                }
            } catch {
                DispatchQueue.main.async { self.tableView.reloadData() }
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
        let importance = item.importance ?? "Monitor"
        let importanceIcon = importance == "Needs immediate attention" ? "🔺" : "👁"
        
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
    
    func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath]) {
        for indexPath in indexPaths {
            guard indexPath.row < inspectionItems.count else { continue }
            let item = inspectionItems[indexPath.row]
            if item.hasPhoto {
                item.getPhotoThumbnail(maxDimension: 300) { _ in }
            }
        }
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
    
    init(inspectionItem: InspectionItem) {
        self.inspectionItem = inspectionItem
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        // Updated title to use new field format
        let primaryLocation = inspectionItem.location ?? "N/A"
        let secondaryLocation = inspectionItem.bayNumber ?? "N/A"
        title = "\(primaryLocation) - \(secondaryLocation)"
        view.backgroundColor = .white
        
        // Add Edit button to navigation bar
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Edit",
            style: .plain,
            target: self,
            action: #selector(editButtonTapped)
        )
        
        // Setup scroll view
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
        
        // Display inspection item details
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16)
        ])
        
        // Add inspection details with updated labels
        addDetailLabel(to: stackView, title: "Primary Location (Area/Aisle)", value: inspectionItem.location ?? "N/A")
        addDetailLabel(to: stackView, title: "Secondary Location (Bay/Level)", value: inspectionItem.bayNumber ?? "N/A")
        let importance = inspectionItem.importance ?? "Monitor"
        let importanceDisplay = importance == "Needs immediate attention" ? "􀇾 Needs immediate attention" : "􀋭 Monitor"
        addDetailLabel(to: stackView, title: "Importance", value: importanceDisplay)
           
        // Add each component group
        addSectionHeader(to: stackView, title: "Issues")
            
        let issueStrings = Issue.labels(from: inspectionItem.recordedIssues())
        if issueStrings.isEmpty {
            let noIssuesLabel = UILabel()
            noIssuesLabel.text = "No issues recorded"
            noIssuesLabel.font = UIFont.systemFont(ofSize: 16)
            noIssuesLabel.textColor = .systemGray
            stackView.addArrangedSubview(noIssuesLabel)
        } else {
            for issueString in issueStrings {
                let issueLabel = UILabel()
                issueLabel.text = issueString
                issueLabel.font = UIFont.systemFont(ofSize: 16)
                issueLabel.numberOfLines = 0
                stackView.addArrangedSubview(issueLabel)
            }
        }
        
        // Add comments
        if let comments = inspectionItem.comments, !comments.isEmpty {
            addSectionHeader(to: stackView, title: "Comments")
            
            let commentsLabel = UILabel()
            commentsLabel.text = comments
            commentsLabel.numberOfLines = 0
            commentsLabel.font = UIFont.systemFont(ofSize: 16)
            
            stackView.addArrangedSubview(commentsLabel)
        }
        
        let photos = inspectionItem.getAllPhotosSync()
        if !photos.isEmpty {
            addSectionHeader(to: stackView, title: photos.count == 1 ? "Photo" : "Photos")
            let location = inspectionItem.location ?? "inspection item"
            for (index, photo) in photos.enumerated() {
                let imageView = UIImageView(image: photo)
                imageView.contentMode = .scaleAspectFit
                imageView.translatesAutoresizingMaskIntoConstraints = false
                imageView.heightAnchor.constraint(equalToConstant: 200).isActive = true
                imageView.isAccessibilityElement = true
                imageView.accessibilityLabel = "Photo \(index + 1) of \(photos.count), \(location)"
                stackView.addArrangedSubview(imageView)
            }
        }
    }
    
    @objc private func editButtonTapped() {
        let editVC = InspectionItemFormViewController(inspectionItem: inspectionItem)
        editVC.delegate = self
        let navController = UINavigationController(rootViewController: editVC)
        present(navController, animated: true)
    }
    
    private func addDetailLabel(to stackView: UIStackView, title: String, value: String) {
        let container = UIView()
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont.boldSystemFont(ofSize: 16)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = UIFont.systemFont(ofSize: 16)
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(titleLabel)
        container.addSubview(valueLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            
            valueLabel.topAnchor.constraint(equalTo: container.topAnchor),
            valueLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            valueLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        stackView.addArrangedSubview(container)
    }
    
    private func addSectionHeader(to stackView: UIStackView, title: String) {
        let separator = UIView()
        separator.backgroundColor = .lightGray
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.heightAnchor.constraint(equalToConstant: 1).isActive = true
        
        let headerLabel = UILabel()
        headerLabel.text = title
        headerLabel.font = UIFont.boldSystemFont(ofSize: 18)
        
        stackView.addArrangedSubview(UIView()) // Add some space
        stackView.addArrangedSubview(separator)
        stackView.addArrangedSubview(headerLabel)
    }
    
    private func addComponentGroup(to stackView: UIStackView, title: String, isChecked: Bool) {
        let container = UIView()
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont.systemFont(ofSize: 16)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let statusImage = UIImageView()
        statusImage.image = isChecked ?
            UIImage(systemName: "checkmark.circle.fill") :
            UIImage(systemName: "xmark.circle")
        statusImage.tintColor = isChecked ? .systemGreen : .systemRed
        statusImage.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(titleLabel)
        container.addSubview(statusImage)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            
            statusImage.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            statusImage.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            statusImage.widthAnchor.constraint(equalToConstant: 24),
            statusImage.heightAnchor.constraint(equalToConstant: 24)
        ])
        
        stackView.addArrangedSubview(container)
    }
}

extension InspectionItemDetailViewController: InspectionItemFormDelegate {
    func didSaveInspectionItem() {
        // Refresh the display with updated data
        DispatchQueue.main.async {
            self.setupUI() // This will update the title and content
        }
    }
}

extension InspectionDetailsViewController: InspectionItemFormDelegate {
    func didSaveInspectionItem() {
        loadInspectionItems()
    }
}

