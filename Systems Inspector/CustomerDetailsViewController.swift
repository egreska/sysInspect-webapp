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
    private let tableView = UITableView()
    private let headerView = UIView()
    private let newInspectionButton = UIButton(type: .system)
    private var headerHeightConstraint: NSLayoutConstraint!
    
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
        startPulsingAnimation() // Start pulsing after view appears
    }
    
    // MARK: - Edit Customer Action
    @objc private func editCustomerTapped() {
        let editCustomerVC = EditCustomerViewController(customer: customer)
        editCustomerVC.delegate = self
        let navController = UINavigationController(rootViewController: editCustomerVC)
        present(navController, animated: true)
    }
    
    // MARK: - Add Inspection Action
    @objc private func addInspectionTapped() {
        // Stop pulsing animation temporarily
        newInspectionButton.layer.removeAnimation(forKey: "pulsing")
        
        // Add a quick scale animation for button press feedback
        UIView.animate(withDuration: 0.1, animations: {
            self.newInspectionButton.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }) { _ in
            UIView.animate(withDuration: 0.1, animations: {
                self.newInspectionButton.transform = CGAffineTransform.identity
            }) { _ in
                // Restart pulsing animation after button press
                self.startPulsingAnimation()
            }
        }
        
        // Navigate to inspection form
        let inspectionFormVC = InspectionFormViewController()
        inspectionFormVC.viewModel = InspectionFormViewModel(customer: customer)
        navigationController?.pushViewController(inspectionFormVC, animated: true)
    }
    
    // MARK: - Pulsing Animation
    private func startPulsingAnimation() {
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
        view.backgroundColor = .white
        
        // Setup header view for customer info
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.backgroundColor = UIColor(white: 0.95, alpha: 1.0)
        
        // Setup New Inspection Button
        newInspectionButton.setTitle("New Inspection", for: .normal)
        newInspectionButton.backgroundColor = UIColor.systemGreen
        newInspectionButton.setTitleColor(.white, for: .normal)
        newInspectionButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        newInspectionButton.layer.cornerRadius = 12
        newInspectionButton.layer.shadowColor = UIColor.black.cgColor
        newInspectionButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        newInspectionButton.layer.shadowOpacity = 0.1
        newInspectionButton.layer.shadowRadius = 4
        newInspectionButton.translatesAutoresizingMaskIntoConstraints = false
        newInspectionButton.addTarget(self, action: #selector(addInspectionTapped), for: .touchUpInside)
        
        // Setup TableView
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "InspectionCell")
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
        
        // Always show these fields
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        
        stackView.addArrangedSubview(createDetailLabel(
            title: "Added:",
            value: dateFormatter.string(from: customer.createdDate ?? Date())
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
        // Ensure a user is logged in
        guard let currentUserID = CoreDataManager.shared.currentUserID else {
            print("CustomerDetailsViewController: No current user ID. Not fetching inspections.")
            inspections = []
            DispatchQueue.main.async {
                self.tableView.reloadData()
                self.updateInspectionCountInHeader()
            }
            return
        }

        // Create a fetch request for the Inspection entity
        let fetchRequest: NSFetchRequest<Inspection> = Inspection.fetchRequest()
        
        // Add a predicate to filter inspections by the current customer AND current user
        let customerPredicate = NSPredicate(format: "customer == %@", customer)
        let userPredicate = NSPredicate(format: "userId == %@", currentUserID as CVarArg)
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [customerPredicate, userPredicate])

        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        
        do {
            inspections = try CoreDataManager.shared.context.fetch(fetchRequest)
            
            // Reload table view data
            DispatchQueue.main.async {
                self.tableView.reloadData()
                // Update the header to reflect the current inspection count
                self.updateInspectionCountInHeader()
            }
        } catch {
            print("Error fetching inspections: \(error)")
        }
    }
}

// MARK: - UITableViewDataSource
extension CustomerDetailsViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return inspections.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "InspectionCell", for: indexPath)
        let inspection = inspections[indexPath.row]

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short

        let dateString: String
        if let inspectionDate = inspection.date {
            dateString = dateFormatter.string(from: inspectionDate)
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
        let inspection = inspections[indexPath.row]
        
        let inspectionDetailsVC = InspectionDetailsViewController(inspection: inspection)
        navigationController?.pushViewController(inspectionDetailsVC, animated: true)
        
        tableView.deselectRow(at: indexPath, animated: true)
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
                
                // Update the inspection count in header
                self.updateInspectionCountInHeader()
            })
            
            present(alert, animated: true)
        }
    }
}

// MARK: - EditCustomerViewControllerDelegate
extension CustomerDetailsViewController: EditCustomerViewControllerDelegate {
    func didUpdateCustomer(_ customer: Customer) {
        self.customer = customer
        title = customer.name
        setupCustomerInfoHeader() // Refresh the header with updated info
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
        let inspectionFormVC = InspectionFormViewController()
        inspectionFormVC.viewModel = InspectionFormViewModel(existingInspection: inspection)
        navigationController?.pushViewController(inspectionFormVC, animated: true)
    }

    private func loadInspectionItems() {
        // NEW: Ensure current user ID exists
        guard let currentUserID = CoreDataManager.shared.currentUserID else {
            print("InspectionDetailsViewController: No current user ID. Not loading inspection items.")
            inspectionItems = []
            DispatchQueue.main.async { self.tableView.reloadData() }
            return
        }

        // Create a fetch request for the InspectionItem entity
        let fetchRequest: NSFetchRequest<InspectionItem> = InspectionItem.fetchRequest()
        
        // Add a predicate to filter items by the current inspection AND current user
        let inspectionPredicate = NSPredicate(format: "inspection == %@", inspection)
        let userPredicate = NSPredicate(format: "userId == %@", currentUserID as CVarArg)
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [inspectionPredicate, userPredicate])

        do {
            inspectionItems = try CoreDataManager.shared.context.fetch(fetchRequest)
            
            // Sort items by creation order
            inspectionItems.sort { item1, item2 in
                let location1 = item1.location ?? ""
                let location2 = item2.location ?? ""
                if location1 == location2 {
                    return (item1.bayNumber ?? "") < (item2.bayNumber ?? "")
                }
                return location1 < location2
            }
            
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        } catch {
            print("Error loading inspection items: \(error)")
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
        
        cell.textLabel?.text = "\(importanceIcon) \(primaryLocation) - \(secondaryLocation)"
        
        let issueStrings = getHierarchicalIssueStrings(for: item)
        cell.detailTextLabel?.text = issueStrings.isEmpty ? "No issues" : issueStrings.joined(separator: "\n")
        cell.detailTextLabel?.numberOfLines = 0
        
        cell.accessoryType = .disclosureIndicator
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        return "Inspection on \(dateFormatter.string(from: inspection.date ?? Date()))"
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
        let editVC = InspectionItemEditViewController(inspectionItem: item)
        editVC.delegate = self
        let navController = UINavigationController(rootViewController: editVC)
        present(navController, animated: true)
    }
    
    private func getHierarchicalIssueStrings(for item: InspectionItem) -> [String] {
        var issueStrings: [String] = []
        
        func addIssueString(_ parentName: String, _ childName: String? = nil, _ grandchildName: String? = nil) {
            var issueString = "• \(parentName)"
            if let child = childName {
                issueString += " > \(child)"
                if let grandchild = grandchildName {
                    issueString += " > \(grandchild)"
                }
            }
            issueStrings.append(issueString)
        }
        
        if item.upright {
            // Check for specific upright sub-issues
            if item.uprightFrontDamage { addIssueString("Upright", "Front", "Damage") }
            if item.uprightFrontTwisted { addIssueString("Upright", "Front", "Twisted") }
            if item.uprightRearDamage { addIssueString("Upright", "Rear", "Damage") }
            if item.uprightRearTwisted { addIssueString("Upright", "Rear", "Twisted") }
            if item.uprightAlignmentOutOfAlignment { addIssueString("Upright", "Alignment", "Out of alignment") }
            if item.uprightAlignmentOutOfVerticalPlumb { addIssueString("Upright", "Alignment", "Out of vertical plumb") }
            
            // If no specific sub-issues, just show parent
            if !item.uprightFrontDamage && !item.uprightFrontTwisted &&
               !item.uprightRearDamage && !item.uprightRearTwisted &&
               !item.uprightAlignmentOutOfAlignment && !item.uprightAlignmentOutOfVerticalPlumb {
                addIssueString("Upright")
            }
        }
        
        if item.beam {
            if item.beamFrontDamage { addIssueString("Beam", "Front damage") }
            if item.beamRearDamage { addIssueString("Beam", "Rear damage") }
            if item.beamFrontBowed { addIssueString("Beam", "Front bowed") }
            if item.beamRearBowed { addIssueString("Beam", "Rear bowed") }
            if !item.beamFrontDamage && !item.beamRearDamage && !item.beamFrontBowed && !item.beamRearBowed {
                addIssueString("Beam")
            }
        }
        
        if item.wireDeck {
            if item.wireDeckMissing { addIssueString("Wire Deck", "Missing") }
            if item.wireDeckDamaged { addIssueString("Wire Deck", "Damaged") }
            if item.wireDeckOutOfPosition { addIssueString("Wire Deck", "Out of position") }
            if !item.wireDeckMissing && !item.wireDeckDamaged && !item.wireDeckOutOfPosition {
                addIssueString("Wire Deck")
            }
        }
        
        if item.basePlate {
            if item.basePlateFloorDamaged { addIssueString("Base Plate", "Floor damaged") }
            if item.basePlateTwisted { addIssueString("Base Plate", "Twisted") }
            if item.basePlateDamaged { addIssueString("Base Plate", "Damaged") }
            if !item.basePlateFloorDamaged && !item.basePlateTwisted && !item.basePlateDamaged {
                addIssueString("Base Plate")
            }
        }
        
        if item.anchors {
            if item.anchorsMissing { addIssueString("Anchors", "Missing anchors or bolts") }
            if item.anchorsDamaged { addIssueString("Anchors", "Damaged or bent") }
            if item.anchorsTorqued { addIssueString("Anchors", "Torqued to 35lbs") }
            if !item.anchorsMissing && !item.anchorsDamaged && !item.anchorsTorqued {
                addIssueString("Anchors")
            }
        }
        
        if item.bracingDamage {
            if item.bracingHorizontal { addIssueString("Bracing Damage", "Horizontal") }
            if item.bracingDiagonal { addIssueString("Bracing Damage", "Diagonal") }
            if !item.bracingHorizontal && !item.bracingDiagonal {
                addIssueString("Bracing Damage")
            }
        }
        
        if item.postProtector {
            if item.postProtectorMissing { addIssueString("Post Protector", "Missing") }
            if item.postProtectorDamaged { addIssueString("Post Protector", "Damaged") }
            if item.postProtectorRepairRequired { addIssueString("Post Protector", "Repair required") }
            if !item.postProtectorMissing && !item.postProtectorDamaged && !item.postProtectorRepairRequired {
                addIssueString("Post Protector")
            }
        }
        
        if item.aisleGuarding {
            if item.aisleGuardingMissing { addIssueString("Aisle Guarding", "Missing") }
            if item.aisleGuardingDamaged { addIssueString("Aisle Guarding", "Damaged") }
            if item.aisleGuardingRepairRequired { addIssueString("Aisle Guarding", "Repair required") }
            if !item.aisleGuardingMissing && !item.aisleGuardingDamaged && !item.aisleGuardingRepairRequired {
                addIssueString("Aisle Guarding")
            }
        }
        
        return issueStrings
    }
}

// MARK: - InspectionItemEditDelegate
extension CustomerDetailsViewController: InspectionItemEditDelegate {
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
            
        let issueStrings = getHierarchicalIssueStrings(for: inspectionItem)
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
        
        // Add photo if available
        if inspectionItem.hasPhoto {
            addSectionHeader(to: stackView, title: "Photo")
            
            let imageView = UIImageView()
            imageView.contentMode = .scaleAspectFit
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.heightAnchor.constraint(equalToConstant: 200).isActive = true
            
            // Show placeholder initially
            imageView.image = UIImage(systemName: "photo")
            imageView.tintColor = .lightGray
            
            // Load photo asynchronously with caching
            inspectionItem.getPhoto { image in
                if let image = image {
                    imageView.image = image
                    print("📸 Displaying photo from cache/CloudKit/local storage")
                } else {
                    print("📸 No photo found, showing placeholder")
                }
            }
            
            stackView.addArrangedSubview(imageView)
        }
    }
    
    private func getHierarchicalIssueStrings(for item: InspectionItem) -> [String] {
        var issueStrings: [String] = []
        
        func addIssueString(_ parentName: String, _ childName: String? = nil, _ grandchildName: String? = nil) {
            var issueString = "• \(parentName)"
            if let child = childName {
                issueString += " > \(child)"
                if let grandchild = grandchildName {
                    issueString += " > \(grandchild)"
                }
            }
            issueStrings.append(issueString)
        }
        
        // Now these calls work without labels
        if item.upright {
                // Check for specific upright sub-issues
                if item.uprightFrontDamage { addIssueString("Upright", "Front", "Damage") }
                if item.uprightFrontTwisted { addIssueString("Upright", "Front", "Twisted") }
                if item.uprightRearDamage { addIssueString("Upright", "Rear", "Damage") }
                if item.uprightRearTwisted { addIssueString("Upright", "Rear", "Twisted") }
                if item.uprightAlignmentOutOfAlignment { addIssueString("Upright", "Alignment", "Out of alignment") }
                if item.uprightAlignmentOutOfVerticalPlumb { addIssueString("Upright", "Alignment", "Out of vertical plumb") }
                
                // If no specific sub-issues, just show parent
                if !item.uprightFrontDamage && !item.uprightFrontTwisted &&
                   !item.uprightRearDamage && !item.uprightRearTwisted &&
                   !item.uprightAlignmentOutOfAlignment && !item.uprightAlignmentOutOfVerticalPlumb {
                    addIssueString("Upright")
                }
            }
            
            if item.beam {
                if item.beamFrontDamage { addIssueString("Beam", "Front damage") }
                if item.beamRearDamage { addIssueString("Beam", "Rear damage") }
                if item.beamFrontBowed { addIssueString("Beam", "Front bowed") }
                if item.beamRearBowed { addIssueString("Beam", "Rear bowed") }
                if !item.beamFrontDamage && !item.beamRearDamage && !item.beamFrontBowed && !item.beamRearBowed {
                    addIssueString("Beam")
                }
            }
            
            if item.wireDeck {
                if item.wireDeckMissing { addIssueString("Wire Deck", "Missing") }
                if item.wireDeckDamaged { addIssueString("Wire Deck", "Damaged") }
                if item.wireDeckOutOfPosition { addIssueString("Wire Deck", "Out of position") }
                if !item.wireDeckMissing && !item.wireDeckDamaged && !item.wireDeckOutOfPosition {
                    addIssueString("Wire Deck")
                }
            }
            
            if item.basePlate {
                if item.basePlateFloorDamaged { addIssueString("Base Plate", "Floor damaged") }
                if item.basePlateTwisted { addIssueString("Base Plate", "Twisted") }
                if item.basePlateDamaged { addIssueString("Base Plate", "Damaged") }
                if !item.basePlateFloorDamaged && !item.basePlateTwisted && !item.basePlateDamaged {
                    addIssueString("Base Plate")
                }
            }
            
            if item.anchors {
                if item.anchorsMissing { addIssueString("Anchors", "Missing anchors or bolts") }
                if item.anchorsDamaged { addIssueString("Anchors", "Damaged or bent") }
                if item.anchorsTorqued { addIssueString("Anchors", "Torqued to 35lbs") }
                if !item.anchorsMissing && !item.anchorsDamaged && !item.anchorsTorqued {
                    addIssueString("Anchors")
                }
            }
            
            if item.bracingDamage {
                if item.bracingHorizontal { addIssueString("Bracing Damage", "Horizontal") }
                if item.bracingDiagonal { addIssueString("Bracing Damage", "Diagonal") }
                if !item.bracingHorizontal && !item.bracingDiagonal {
                    addIssueString("Bracing Damage")
                }
            }
            
            if item.postProtector {
                if item.postProtectorMissing { addIssueString("Post Protector", "Missing") }
                if item.postProtectorDamaged { addIssueString("Post Protector", "Damaged") }
                if item.postProtectorRepairRequired { addIssueString("Post Protector", "Repair required") }
                if !item.postProtectorMissing && !item.postProtectorDamaged && !item.postProtectorRepairRequired {
                    addIssueString("Post Protector")
                }
            }
            
            if item.aisleGuarding {
                if item.aisleGuardingMissing { addIssueString("Aisle Guarding", "Missing") }
                if item.aisleGuardingDamaged { addIssueString("Aisle Guarding", "Damaged") }
                if item.aisleGuardingRepairRequired { addIssueString("Aisle Guarding", "Repair required") }
                if !item.aisleGuardingMissing && !item.aisleGuardingDamaged && !item.aisleGuardingRepairRequired {
                    addIssueString("Aisle Guarding")
                }
            }
            
            return issueStrings
        }
    
    @objc private func editButtonTapped() {
        let editVC = InspectionItemEditViewController(inspectionItem: inspectionItem)
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

extension InspectionItemDetailViewController: InspectionItemEditDelegate {
    func didSaveInspectionItem() {
        // Refresh the display with updated data
        DispatchQueue.main.async {
            self.setupUI() // This will update the title and content
        }
    }
}

// MARK: - InspectionItemEditViewController
protocol InspectionItemEditDelegate: AnyObject {
    func didSaveInspectionItem()
}

class InspectionItemEditViewController: UIViewController {
    weak var delegate: InspectionItemEditDelegate?
    private let inspectionItem: InspectionItem
    private var selectedComponents: [DamageComponent] = []
    private var damageHierarchy: [DamageComponent] = []
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let stackView = UIStackView()
    
    private let primaryLocationTextField = UITextField()
    private let secondaryLocationTextField = UITextField()
    private var currentImportance: String = "Monitor"
    private let importanceToggleButton = UIButton(type: .system)
    private let issueDropdownButton = UIButton(type: .system)
    private let selectedIssueLabel = UILabel()
    private let commentsTextView = UITextView()
    
    // NEW: Add a photo property to potentially store a new photo taken during edit
    private var newPhoto: UIImage?
    private var photoURL: URL? // This will store the local URL if a new photo is taken
    private let cameraButton: UIButton = { // Add camera button similar to InspectionFormVC
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
    private let cameraButtonLabel: UILabel = { // Label for camera button
        let label = UILabel()
        label.text = "Take Photo"
        label.font = UIFont.systemFont(ofSize: 14)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()


    init(inspectionItem: InspectionItem) {
        self.inspectionItem = inspectionItem
        super.init(nibName: nil, bundle: nil)
        // Store existing photo URL if present for display or re-upload
        if let existingPhotoPath = inspectionItem.photoURL {
            self.photoURL = URL(fileURLWithPath: existingPhotoPath)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupDamageComponents()
        populateFormWithExistingData()
        setupActions() // NEW: Setup actions for new camera button
        setupTextViewDelegate() // NEW: Ensure text view delegate is set
    }
    
    private func setupUI() {
        title = "Edit Item"
        view.backgroundColor = .white
        
        // Navigation buttons
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
        
        // Setup scroll view and stack view
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(stackView)
        
        // Setup text fields
        primaryLocationTextField.placeholder = "Area/Aisle"
        primaryLocationTextField.borderStyle = .roundedRect
        primaryLocationTextField.translatesAutoresizingMaskIntoConstraints = false
        
        secondaryLocationTextField.placeholder = "Bay/Level (Optional)"
        secondaryLocationTextField.borderStyle = .roundedRect
        secondaryLocationTextField.translatesAutoresizingMaskIntoConstraints = false
        
        // Setup issue button
        issueDropdownButton.setTitle("Select Issue", for: .normal)
        issueDropdownButton.backgroundColor = UIColor.systemGray6
        issueDropdownButton.setTitleColor(.systemBlue, for: .normal)
        issueDropdownButton.layer.cornerRadius = 8
        issueDropdownButton.layer.borderWidth = 1
        issueDropdownButton.layer.borderColor = UIColor.systemGray4.cgColor
        issueDropdownButton.contentHorizontalAlignment = .left
        
        // Use modern configuration for iOS 15+, fallback for older versions
        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.plain()
            config.title = "Select Issue"
            config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 0)
            config.baseForegroundColor = .systemBlue
            issueDropdownButton.configuration = config
        } else {
            issueDropdownButton.titleEdgeInsets = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 0)
        }
        
        issueDropdownButton.translatesAutoresizingMaskIntoConstraints = false
        // Target for issueDropdownButton already set
        
        // Setup selected issue label
        selectedIssueLabel.text = "No issue selected"
        selectedIssueLabel.font = UIFont.systemFont(ofSize: 14)
        selectedIssueLabel.textColor = .systemGray
        selectedIssueLabel.numberOfLines = 0
        selectedIssueLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Setup comments text view
        commentsTextView.layer.borderWidth = 1
        commentsTextView.layer.borderColor = UIColor.lightGray.cgColor
        commentsTextView.layer.cornerRadius = 5
        commentsTextView.translatesAutoresizingMaskIntoConstraints = false
        // Delegate for commentsTextView already set
        
        // Add to stack view
        let primaryLocationContainer = createLabeledField(labelText: "Primary Location:", field: primaryLocationTextField)
        let secondaryLocationContainer = createLabeledField(labelText: "Secondary Location:", field: secondaryLocationTextField)
        let issueContainer = createIssueContainer()
        let importanceContainer = createImportanceContainer()
        let commentsContainer = createLabeledField(labelText: "Comments:", field: commentsTextView)
        
        // NEW: Camera button container
        let cameraButtonContainer = UIView()
        cameraButtonContainer.translatesAutoresizingMaskIntoConstraints = false
        cameraButtonContainer.addSubview(cameraButton)
        cameraButtonContainer.addSubview(cameraButtonLabel)
        NSLayoutConstraint.activate([
            cameraButton.centerXAnchor.constraint(equalTo: cameraButtonContainer.centerXAnchor),
            cameraButton.topAnchor.constraint(equalTo: cameraButtonContainer.topAnchor),
            cameraButton.widthAnchor.constraint(equalToConstant: 60),
            cameraButton.heightAnchor.constraint(equalToConstant: 60),
            cameraButtonLabel.topAnchor.constraint(equalTo: cameraButton.bottomAnchor, constant: 8),
            cameraButtonLabel.centerXAnchor.constraint(equalTo: cameraButtonContainer.centerXAnchor),
            cameraButtonLabel.bottomAnchor.constraint(equalTo: cameraButtonContainer.bottomAnchor),
            cameraButtonContainer.heightAnchor.constraint(equalToConstant: 90) // Ensure enough height for button and label
        ])


        [primaryLocationContainer,
         secondaryLocationContainer,
         issueContainer,
         importanceContainer,
         commentsContainer,
         cameraButtonContainer // NEW: Add camera button to stack
        ].forEach { stackView.addArrangedSubview($0) }
        
        // Setup constraints
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
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
            
            commentsTextView.heightAnchor.constraint(equalToConstant: 100)
        ])
    }

    // NEW: Setup actions for camera button
    private func setupActions() {
        issueDropdownButton.addTarget(self, action: #selector(issueDropdownTapped), for: .touchUpInside)
        importanceToggleButton.addTarget(self, action: #selector(importanceToggleTapped), for: .touchUpInside)
        cameraButton.addTarget(self, action: #selector(cameraTapped), for: .touchUpInside)
    }

    // NEW: Setup text view delegate
    private func setupTextViewDelegate() {
        commentsTextView.delegate = self
    }

    private func setupDamageComponents() {
        damageHierarchy = createDamageHierarchy()
    }
    
    private func createImportanceContainer() -> UIView {
            let container = UIView()
            
            let label = UILabel()
            label.text = "Importance:"
            label.font = UIFont.boldSystemFont(ofSize: 16)
            label.translatesAutoresizingMaskIntoConstraints = false
            
            importanceToggleButton.backgroundColor = UIColor.systemGray6
            importanceToggleButton.layer.cornerRadius = 8
            importanceToggleButton.layer.borderWidth = 1
            importanceToggleButton.layer.borderColor = UIColor.systemGray4.cgColor
            importanceToggleButton.translatesAutoresizingMaskIntoConstraints = false
            importanceToggleButton.addTarget(self, action: #selector(importanceToggleTapped), for: .touchUpInside)
            
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
            
            // Use modern configuration for iOS 15+, fallback for older versions
            if #available(iOS 15.0, *) {
                var config = importanceToggleButton.configuration ?? UIButton.Configuration.plain()
                config.imagePadding = 8
                config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 0)
                importanceToggleButton.configuration = config
            } else {
                importanceToggleButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 0)
                importanceToggleButton.titleEdgeInsets = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 0)
            }
        }
        
        @objc private func importanceToggleTapped() {
            currentImportance = (currentImportance == "Monitor") ? "Needs immediate attention" : "Monitor"
            updateImportanceToggleDisplay()
        }
    
    private func populateFormWithExistingData() {
            // Populate text fields
            primaryLocationTextField.text = inspectionItem.location
            secondaryLocationTextField.text = inspectionItem.bayNumber
            
            // Populate comments
            if let comments = inspectionItem.comments, !comments.isEmpty {
                commentsTextView.text = comments
                commentsTextView.textColor = .label
            } else {
                commentsTextView.text = "Enter comments here..."
                commentsTextView.textColor = UIColor.lightGray
            }
            
            // Populate selected damage components
            selectedComponents = getSelectedDamageComponents(from: inspectionItem)
            setDamageComponentsSelection(selectedComponents)
            updateSelectedIssueDisplay()
        
            // Populate importance
            currentImportance = inspectionItem.importance ?? "Monitor"
            updateImportanceToggleDisplay()

            // Update camera button to show existing photo if available
            if let photoPath = inspectionItem.photoURL, FileManager.default.fileExists(atPath: photoPath) {
                let configuration = UIImage.SymbolConfiguration(pointSize: 24, weight: .medium)
                let checkmarkImage = UIImage(systemName: "checkmark.circle.fill", withConfiguration: configuration)
                cameraButton.setImage(checkmarkImage, for: .normal)
            } else {
                let configuration = UIImage.SymbolConfiguration(pointSize: 24, weight: .medium)
                let cameraImage = UIImage(systemName: "camera.fill", withConfiguration: configuration)
                cameraButton.setImage(cameraImage, for: .normal)
            }
        }
    
    private func getSelectedDamageComponents(from item: InspectionItem) -> [DamageComponent] {
        var components: [DamageComponent] = []
        
        func findAndAddComponent(named name: String, parentName: String? = nil, grandparentName: String? = nil, in hierarchy: [DamageComponent]) {
            for component in hierarchy {
                if component.name == name {
                    if let grandparent = grandparentName, let parent = parentName {
                        // Check three-level hierarchy
                        if component.parent?.name == parent && component.parent?.parent?.name == grandparent {
                            components.append(component)
                            return
                        }
                    } else if let parent = parentName {
                        // Check two-level hierarchy
                        if component.parent?.name == parent {
                            components.append(component)
                            return
                        }
                    } else if component.parent == nil {
                        // Top-level component
                        components.append(component)
                        return
                    }
                }
                findAndAddComponent(named: name, parentName: parentName, grandparentName: grandparentName, in: component.children)
            }
        }
        
        // UPDATED: Add specific upright components
        if item.uprightFrontDamage { findAndAddComponent(named: "Damage", parentName: "Front", grandparentName: "Upright", in: damageHierarchy) }
        if item.uprightFrontTwisted { findAndAddComponent(named: "Twisted", parentName: "Front", grandparentName: "Upright", in: damageHierarchy) }
        if item.uprightRearDamage { findAndAddComponent(named: "Damage", parentName: "Rear", grandparentName: "Upright", in: damageHierarchy) }
        if item.uprightRearTwisted { findAndAddComponent(named: "Twisted", parentName: "Rear", grandparentName: "Upright", in: damageHierarchy) }
        if item.uprightAlignmentOutOfAlignment { findAndAddComponent(named: "Out of alignment", parentName: "Alignment", grandparentName: "Upright", in: damageHierarchy) }
        if item.uprightAlignmentOutOfVerticalPlumb { findAndAddComponent(named: "Out of vertical plumb", parentName: "Alignment", grandparentName: "Upright", in: damageHierarchy) }
        
        // If no specific upright sub-issues but upright is true, add the parent
        if item.upright && !item.uprightFrontDamage && !item.uprightFrontTwisted &&
           !item.uprightRearDamage && !item.uprightRearTwisted &&
           !item.uprightAlignmentOutOfAlignment && !item.uprightAlignmentOutOfVerticalPlumb {
            findAndAddComponent(named: "Upright", in: damageHierarchy)
        }
        if item.beam { findAndAddComponent(named: "Beam", in: damageHierarchy) }
        if item.wireDeck { findAndAddComponent(named: "Wire Deck", in: damageHierarchy) }
        if item.basePlate { findAndAddComponent(named: "Base Plate", in: damageHierarchy) }
        if item.anchors { findAndAddComponent(named: "Anchors", in: damageHierarchy) }
        if item.bracingDamage { findAndAddComponent(named: "Bracing Damage", in: damageHierarchy) }
        if item.postProtector { findAndAddComponent(named: "Post Protector", in: damageHierarchy) }
        if item.aisleGuarding { findAndAddComponent(named: "Aisle Guarding", in: damageHierarchy) }
        
        return components
    }
    
    private func setDamageComponentsSelection(_ components: [DamageComponent]) {
        // Reset all selections first
        func resetComponent(_ component: DamageComponent) {
            component.isSelected = false
            component.children.forEach { resetComponent($0) }
        }
        damageHierarchy.forEach { resetComponent($0) }
        
        // Set selected components
        components.forEach { $0.isSelected = true }
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
    
    private func createDamageHierarchy() -> [DamageComponent] {
        // Same hierarchy creation as in InspectionFormViewController
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
    
    @objc private func cancelTapped() {
        dismiss(animated: true)
    }
    
    @objc private func saveTapped() {
        guard validateForm() else { return }
        
        guard inspectionItem.userId != nil else {
            showAlert(message: "Inspection item is missing user ID. Cannot save changes.")
            return
        }

        // Update the inspection item with new values
        inspectionItem.location = primaryLocationTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        inspectionItem.bayNumber = secondaryLocationTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        inspectionItem.importance = currentImportance
        
        if commentsTextView.textColor != UIColor.lightGray {
            inspectionItem.comments = commentsTextView.text
        } else {
            inspectionItem.comments = nil
        }
        
        // Reset all damage component flags
        resetInspectionItemDamageFlags(inspectionItem)
        
        // Set new damage component flags
        updateInspectionItemWithSelectedComponents(inspectionItem)
        
        // UPDATED: Handle new photo for CloudKit sync
        if let newPhoto = newPhoto {
            // Save locally for immediate access
            let localPhotoURL = saveImageToDocuments(image: newPhoto)
            inspectionItem.photoURL = localPhotoURL?.path
            
            // CRITICAL: Save to Core Data for CloudKit sync
            if let photoData = newPhoto.jpegData(compressionQuality: 0.8) {
                inspectionItem.photoData = photoData
                print("💾 Updated photo data in Core Data for CloudKit sync (\(photoData.count) bytes)")
            }
        }
        
        // Save to Core Data. CloudKit will handle sync automatically.
        CoreDataManager.shared.saveContext()
        
        // Notify delegate and dismiss
        delegate?.didSaveInspectionItem()
        dismiss(animated: true)
    }
    
    // NEW: Function to save image to local documents (moved from InspectionFormViewModel for consistency)
    private func saveImageToDocuments(image: UIImage) -> URL? {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }
        let fileName = "\(UUID().uuidString).jpg" // Use UUID for unique filenames
        let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(fileName)
        
        do {
            try data.write(to: fileURL)
            print("Saved image locally to: \(fileURL.lastPathComponent) for item edit.")
            return fileURL
        } catch {
            print("Error saving image locally during item edit: \(error)")
            return nil
        }
    }

    // NEW: Action for camera button
    @objc private func cameraTapped() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            showAlert(message: "Camera is not available")
            return
        }
        
        let imagePicker = UIImagePickerController()
        imagePicker.sourceType = .camera
        imagePicker.delegate = self // Set self as delegate
        present(imagePicker, animated: true)
    }

    private func resetInspectionItemDamageFlags(_ item: InspectionItem) {
        item.upright = false
        item.uprightFrontDamage = false
        item.uprightFrontTwisted = false
        item.uprightRearDamage = false
        item.uprightRearTwisted = false
        item.uprightAlignmentOutOfAlignment = false
        item.uprightAlignmentOutOfVerticalPlumb = false
        item.beam = false
        item.wireDeck = false
        item.basePlate = false
        item.anchors = false
        item.bracingDamage = false
        item.postProtector = false
        item.aisleGuarding = false
        item.beamFrontDamage = false
        item.beamRearDamage = false
        item.beamFrontBowed = false
        item.beamRearBowed = false
        item.wireDeckMissing = false
        item.wireDeckDamaged = false
        item.wireDeckOutOfPosition = false
        item.basePlateFloorDamaged = false
        item.basePlateTwisted = false
        item.basePlateDamaged = false
        item.anchorsMissing = false
        item.anchorsDamaged = false
        item.anchorsTorqued = false
        item.bracingHorizontal = false
        item.bracingDiagonal = false
        item.postProtectorMissing = false
        item.postProtectorDamaged = false
        item.postProtectorRepairRequired = false
        item.aisleGuardingMissing = false
        item.aisleGuardingDamaged = false
        item.aisleGuardingRepairRequired = false
    }
    
    private func updateInspectionItemWithSelectedComponents(_ item: InspectionItem) {
        for component in selectedComponents {
            switch component.name {
            case "Upright":
                item.upright = true
            case "Front" where component.parent?.name == "Upright": // Handle intermediate nodes
                break
            case "Rear" where component.parent?.name == "Upright": // Handle intermediate nodes
                break
            case "Alignment" where component.parent?.name == "Upright": // Handle intermediate nodes
                break
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
    extension InspectionItemEditViewController: UITextViewDelegate {
        func textViewDidBeginEditing(_ textView: UITextView) {
            if textView.textColor == UIColor.lightGray {
                textView.text = ""
                textView.textColor = UIColor.label
            }
        }
        
        func textViewDidEndEditing(_ textView: UITextView) {
            if textView.text.isEmpty {
                textView.text = "Enter comments here..."
                textView.textColor = UIColor.lightGray
            }
        }
    }

    // MARK: - DamageComponentSelectionDelegate
    extension InspectionItemEditViewController: DamageComponentSelectionDelegate {
        func didSelectDamageComponents(_ components: [DamageComponent]) {
            selectedComponents = components
            updateSelectedIssueDisplay()
        }
    }

// MARK: - UIImagePickerControllerDelegate, UINavigationControllerDelegate (for InspectionItemEditViewController)
extension InspectionItemEditViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let image = info[.originalImage] as? UIImage {
            self.newPhoto = image
            let configuration = UIImage.SymbolConfiguration(pointSize: 24, weight: .medium)
            let checkmarkImage = UIImage(systemName: "checkmark.circle.fill", withConfiguration: configuration)
            cameraButton.setImage(checkmarkImage, for: .normal)
        }
        picker.dismiss(animated: true)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}

extension InspectionDetailsViewController: InspectionItemEditDelegate {
    func didSaveInspectionItem() {
        // Refresh the inspection items list
        loadInspectionItems()
    }
}
