//
//  ReportViewController.swift
//  Systems Inspector
//
//  Created by Eric Greska on 5/22/25.
import UIKit
import CoreData

class ReportViewController: UIViewController {
    
    // MARK: - Properties
    private let reportGenerator = ReportGenerator()
    private var inspections: [Inspection] = []
    private var selectedInspection: Inspection?
    private var selectedSortCriteria: SortCriteria = .entryOrder
    private var activeFilters: [Filter] = []
    
    // MARK: - UI Components
    private let tableView = UITableView()
    private let filterButton = UIButton(type: .system)
    private let sortButton = UIButton(type: .system)
    private let generatePDFButton = UIButton(type: .system)
    private let generateCSVButton = UIButton(type: .system)
    private let noDataLabel = UILabel()
    
    // MARK: - Color and Style Constants
        private struct SortStyles {
            // Use emoji and text formatting for visual distinction
            static let itemLevelPrefix = "🔵 " // Blue circle for item-level
            static let inspectionLevelPrefix = "🟢 " // Green circle for inspection-level
            static let selectedPrefix = "✅ " // Checkmark for selected
            static let separatorPrefix = "━━━━ " // Visual separator
        }
    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        fetchInspections()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        fetchInspections()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        title = "Generate Reports"
        view.backgroundColor = .white
        
        // Setup TableView
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "InspectionCell")
        tableView.dataSource = self
        tableView.delegate = self
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.tableFooterView = UIView() // Remove empty cell separators
        
        // Setup No Data Label
        noDataLabel.text = "No inspections available. Create an inspection first."
        noDataLabel.textAlignment = .center
        noDataLabel.textColor = .darkGray
        noDataLabel.font = UIFont.systemFont(ofSize: 16)
        noDataLabel.translatesAutoresizingMaskIntoConstraints = false
        noDataLabel.isHidden = true
        
        // Setup Filter Button
        filterButton.setTitle("Filter", for: .normal)
        filterButton.addTarget(self, action: #selector(showFilterOptions), for: .touchUpInside)
        filterButton.translatesAutoresizingMaskIntoConstraints = false
        
        // Setup Sort Button
        sortButton.setTitle("Sort By: Entry Order", for: .normal) // CHANGED from "Sort By: Date"
        sortButton.addTarget(self, action: #selector(showSortOptions), for: .touchUpInside)
        sortButton.translatesAutoresizingMaskIntoConstraints = false
        
        // Setup Generate PDF Button
        generatePDFButton.setTitle("Generate PDF Report", for: .normal)
        generatePDFButton.addTarget(self, action: #selector(generatePDFReport), for: .touchUpInside)
        generatePDFButton.backgroundColor = UIColor.systemBlue
        generatePDFButton.setTitleColor(.white, for: .normal)
        generatePDFButton.layer.cornerRadius = 8
        generatePDFButton.translatesAutoresizingMaskIntoConstraints = false
        
        // Setup Generate CSV Button
        generateCSVButton.setTitle("Generate CSV Report", for: .normal)
        generateCSVButton.addTarget(self, action: #selector(generateCSVReport), for: .touchUpInside)
        generateCSVButton.backgroundColor = UIColor.systemGreen
        generateCSVButton.setTitleColor(.white, for: .normal)
        generateCSVButton.layer.cornerRadius = 8
        generateCSVButton.translatesAutoresizingMaskIntoConstraints = false
        
        // Create button stack
        let buttonStack = UIStackView(arrangedSubviews: [generatePDFButton, generateCSVButton])
        buttonStack.axis = .horizontal
        buttonStack.spacing = 10
        buttonStack.distribution = .fillEqually
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        
        // Create filter/sort stack
        let filterSortStack = UIStackView(arrangedSubviews: [filterButton, sortButton])
        filterSortStack.axis = .horizontal
        filterSortStack.spacing = 10
        filterSortStack.distribution = .fillEqually
        filterSortStack.translatesAutoresizingMaskIntoConstraints = false
        
        // Add subviews
        view.addSubview(filterSortStack)
        view.addSubview(tableView)
        view.addSubview(buttonStack)
        view.addSubview(noDataLabel)
        
        // Layout Constraints
        NSLayoutConstraint.activate([
            filterSortStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            filterSortStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            filterSortStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            tableView.topAnchor.constraint(equalTo: filterSortStack.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: buttonStack.topAnchor, constant: -16),
            
            buttonStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            buttonStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            buttonStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            buttonStack.heightAnchor.constraint(equalToConstant: 50),
            
            noDataLabel.centerXAnchor.constraint(equalTo: tableView.centerXAnchor),
            noDataLabel.centerYAnchor.constraint(equalTo: tableView.centerYAnchor)
        ])
    }
    
    // MARK: - Updated Data Fetching in ReportViewController.swift
    private func fetchInspections() {
        let fetchRequest: NSFetchRequest<Inspection> = Inspection.fetchRequest()
        
        // Apply active filters
        if !activeFilters.isEmpty {
            var predicates: [NSPredicate] = []
            
            for filter in activeFilters {
                switch filter.key {
                case "customer":
                    predicates.append(NSPredicate(format: "customer.name CONTAINS[cd] %@", filter.value))
                case "date":
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd"
                    if let date = dateFormatter.date(from: filter.value) {
                        predicates.append(NSPredicate(format: "date >= %@ AND date < %@",
                                                    date as NSDate,
                                                    date.addingTimeInterval(86400) as NSDate))
                    }
                case "inspector":
                    predicates.append(NSPredicate(format: "inspectorName CONTAINS[cd] %@", filter.value))
                default:
                    break
                }
            }
            
            if !predicates.isEmpty {
                fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
            }
        }
        
        // UPDATED: Apply inspection-level sorting only for inspection-level criteria
        switch selectedSortCriteria {
        case .date:
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        case .customer:
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "customer.name", ascending: true)]
        case .inspectionStatus:
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        case .importance, .primaryLocation, .issue, .entryOrder:
            // For item-level sorting, sort inspections by date to maintain some order
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        }
        
        do {
            inspections = try CoreDataManager.shared.context.fetch(fetchRequest)
            tableView.reloadData()
            
            // Show/hide no data label
            noDataLabel.isHidden = !inspections.isEmpty
            
            // Clear selection if the selected inspection is no longer in the list
            if let selectedInspection = selectedInspection, !inspections.contains(selectedInspection) {
                self.selectedInspection = nil
            }
        } catch {
            print("Error fetching inspections: \(error)")
        }
    }
    
    private func sortInspectionItems(for inspections: [Inspection]) -> [Inspection] {
        // For item-level sorting, we need to sort the items within each inspection
        guard case .importance = selectedSortCriteria,
              case .primaryLocation = selectedSortCriteria,
              case .issue = selectedSortCriteria,
              case .entryOrder = selectedSortCriteria else {
            return inspections // No item sorting needed
        }
        
        for inspection in inspections {
            if let items = inspection.items as? Set<InspectionItem> {
                let sortedItems = sortItems(Array(items), criteria: selectedSortCriteria)
                
                // Clear existing items and re-add in sorted order
                inspection.removeFromItems(NSSet(array: Array(items)))
                for item in sortedItems {
                    inspection.addToItems(item)
                }
            }
        }
        
        return inspections
    }
    
    private func sortItems(_ items: [InspectionItem], criteria: SortCriteria) -> [InspectionItem] {
        switch criteria {
        case .importance:
            return items.sorted { item1, item2 in
                let importance1 = item1.importance ?? "Monitor"
                let importance2 = item2.importance ?? "Monitor"
                
                // "Needs immediate attention" comes first
                if importance1 == "Needs immediate attention" && importance2 == "Monitor" {
                    return true
                } else if importance1 == "Monitor" && importance2 == "Needs immediate attention" {
                    return false
                }
                
                // If same importance, sort by primary location
                return (item1.location ?? "") < (item2.location ?? "")
            }
            
        case .primaryLocation:
            return items.sorted { item1, item2 in
                let location1 = item1.location ?? ""
                let location2 = item2.location ?? ""
                
                if location1 == location2 {
                    // If same primary location, sort by secondary location
                    return (item1.bayNumber ?? "") < (item2.bayNumber ?? "")
                }
                
                return location1 < location2
            }
            
        case .issue:
            return items.sorted { item1, item2 in
                let issue1 = getPrimaryIssueType(for: item1)
                let issue2 = getPrimaryIssueType(for: item2)
                
                if issue1 == issue2 {
                    // If same issue type, sort by primary location
                    return (item1.location ?? "") < (item2.location ?? "")
                }
                
                return issue1 < issue2
            }
            
        case .entryOrder:
            // Sort by the order they were created (using ID as a proxy for creation order)
            return items.sorted { item1, item2 in
                return item1.id?.uuidString ?? "" < item2.id?.uuidString ?? ""
            }
            
        default:
            return items // No sorting for inspection-level criteria
        }
    }

    private func getPrimaryIssueType(for item: InspectionItem) -> String {
        // Return the first (primary) issue type found
        if item.upright { return "Upright" }
        if item.beam { return "Beam" }
        if item.wireDeck { return "Wire Deck" }
        if item.basePlate { return "Base Plate" }
        if item.anchors { return "Anchors" }
        if item.bracingDamage { return "Bracing Damage" }
        if item.postProtector { return "Post Protector" }
        if item.aisleGuarding { return "Aisle Guarding" }
        return "No Issues"
    }
    // MARK: - Button Actions
    @objc private func showFilterOptions() {
        let alertController = UIAlertController(title: "Filter Reports", message: "Select filter criteria", preferredStyle: .actionSheet)
        
        alertController.addAction(UIAlertAction(title: "By Customer", style: .default) { [weak self] _ in
            self?.showCustomerFilterInput()
        })
        
        alertController.addAction(UIAlertAction(title: "By Date", style: .default) { [weak self] _ in
            self?.showDateFilterInput()
        })
        
        alertController.addAction(UIAlertAction(title: "By Inspector", style: .default) { [weak self] _ in
            self?.showInspectorFilterInput()
        })
        
        alertController.addAction(UIAlertAction(title: "Clear All Filters", style: .destructive) { [weak self] _ in
            self?.activeFilters = []
            self?.fetchInspections()
        })
        
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // For iPad support
        if let popoverController = alertController.popoverPresentationController {
            popoverController.sourceView = filterButton
            popoverController.sourceRect = filterButton.bounds
        }
        
        present(alertController, animated: true)
    }
    
    // MARK: - Fixed Sort Options Method
        @objc private func showSortOptions() {
            let alertController = UIAlertController(title: "Sort Reports", message: "🔵 Item Sorting  🟢 Inspection Sorting", preferredStyle: .actionSheet)
            
            // ITEM-LEVEL SORTING (Blue indicators)
            let entryOrderAction = UIAlertAction(
                title: createSortTitle("As Entered (Original Order)", isItemLevel: true, isSelected: selectedSortCriteria == .entryOrder),
                style: .default
            ) { [weak self] _ in
                self?.updateSortCriteria(.entryOrder, title: "Sort By: Entry Order")
            }
            alertController.addAction(entryOrderAction)
            
            let importanceAction = UIAlertAction(
                title: createSortTitle("By Importance", isItemLevel: true, isSelected: selectedSortCriteria == .importance),
                style: .default
            ) { [weak self] _ in
                self?.updateSortCriteria(.importance, title: "Sort By: Importance")
            }
            alertController.addAction(importanceAction)
            
            let primaryLocationAction = UIAlertAction(
                title: createSortTitle("By Primary Location", isItemLevel: true, isSelected: selectedSortCriteria == .primaryLocation),
                style: .default
            ) { [weak self] _ in
                self?.updateSortCriteria(.primaryLocation, title: "Sort By: Primary Location")
            }
            alertController.addAction(primaryLocationAction)
            
            let issueAction = UIAlertAction(
                title: createSortTitle("By Issue Type", isItemLevel: true, isSelected: selectedSortCriteria == .issue),
                style: .default
            ) { [weak self] _ in
                self?.updateSortCriteria(.issue, title: "Sort By: Issue Type")
            }
            alertController.addAction(issueAction)
            
            // SEPARATOR - FIXED: Added the missing parameter
            let separatorAction = UIAlertAction(title: "━━━━ Inspection Sorting ━━━━", style: .default) { _ in
                // Empty action - separator only
            }
            separatorAction.isEnabled = false
            alertController.addAction(separatorAction)
            
            // INSPECTION-LEVEL SORTING (Green indicators)
            let dateAction = UIAlertAction(
                title: createSortTitle("By Date", isItemLevel: false, isSelected: selectedSortCriteria == .date),
                style: .default
            ) { [weak self] _ in
                self?.updateSortCriteria(.date, title: "Sort By: Date")
            }
            alertController.addAction(dateAction)
            
            let customerAction = UIAlertAction(
                title: createSortTitle("By Customer", isItemLevel: false, isSelected: selectedSortCriteria == .customer),
                style: .default
            ) { [weak self] _ in
                self?.updateSortCriteria(.customer, title: "Sort By: Customer")
            }
            alertController.addAction(customerAction)
            
            let statusAction = UIAlertAction(
                title: createSortTitle("By Status", isItemLevel: false, isSelected: selectedSortCriteria == .inspectionStatus),
                style: .default
            ) { [weak self] _ in
                self?.updateSortCriteria(.inspectionStatus, title: "Sort By: Status")
            }
            alertController.addAction(statusAction)
            
            // CANCEL ACTION
            alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            
            // For iPad support
            if let popoverController = alertController.popoverPresentationController {
                popoverController.sourceView = sortButton
                popoverController.sourceRect = sortButton.bounds
            }
            
            present(alertController, animated: true)
        }
        
        // MARK: - Helper Methods
        
        private func createSortTitle(_ baseTitle: String, isItemLevel: Bool, isSelected: Bool) -> String {
            var title = ""
            
            if isSelected {
                title = SortStyles.selectedPrefix + baseTitle
            } else if isItemLevel {
                title = SortStyles.itemLevelPrefix + baseTitle
            } else {
                title = SortStyles.inspectionLevelPrefix + baseTitle
            }
            
            return title
        }
        
        private func updateSortCriteria(_ criteria: SortCriteria, title: String) {
            selectedSortCriteria = criteria
            sortButton.setTitle(title, for: .normal)
            fetchInspections()
        }
        
        // MARK: - Updated Report Generation Methods
        @objc private func generatePDFReport() {
            guard let inspection = selectedInspection ?? inspections.first else {
                showAlert(message: "No inspection selected. Please select an inspection from the list.")
                return
            }
            
            // UPDATED: Always pass the current sort criteria since entry order is now a valid item-level sort
            let reportData = reportGenerator.generatePDFReport(inspection: inspection, sortCriteria: selectedSortCriteria)
            saveAndShareReport(data: reportData, fileName: "RackInspector_Report.pdf", mimeType: "application/pdf")
        }

        @objc private func generateCSVReport() {
            guard !inspections.isEmpty else {
                showAlert(message: "No inspections available to generate a report.")
                return
            }
            
            // UPDATED: Always pass the current sort criteria
            guard let reportPackage = reportGenerator.generateCSVReportWithPhotos(inspections: inspections, sortCriteria: selectedSortCriteria) else {
                showAlert(message: "Failed to generate CSV report.")
                return
            }
            
            saveAndShareReportPackage(reportPackage)
        }
    
    // New method to handle report package sharing
    private func saveAndShareReportPackage(_ reportPackage: ReportPackage) {
        let tempDirectory = FileManager.default.temporaryDirectory
        let csvURL = tempDirectory.appendingPathComponent(reportPackage.csvFileName)
        
        var itemsToShare: [URL] = []
        
        do {
            // Save CSV file
            try reportPackage.csvData.write(to: csvURL)
            itemsToShare.append(csvURL)
            
            // Save zip file if photos exist
            if let zipData = reportPackage.zipData {
                let zipURL = tempDirectory.appendingPathComponent(reportPackage.zipFileName)
                try zipData.write(to: zipURL)
                itemsToShare.append(zipURL)
            }
            
            // Present activity controller with both files
            let activityViewController = UIActivityViewController(
                activityItems: itemsToShare,
                applicationActivities: nil
            )
            
            // Customize the activity controller
            activityViewController.setValue("Rack Inspector Report", forKey: "subject")
            
            // For iPad support
            if let popoverController = activityViewController.popoverPresentationController {
                popoverController.sourceView = view
                popoverController.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
                popoverController.permittedArrowDirections = []
            }
            
            present(activityViewController, animated: true)
            
        } catch {
            print("Error saving report package: \(error)")
            showAlert(message: "Failed to save the report files.")
        }
    }

    // Keep the existing saveAndShareReport method for PDF reports
    private func saveAndShareReport(data: Data, fileName: String, mimeType: String) {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try data.write(to: fileURL)
            
            let activityViewController = UIActivityViewController(
                activityItems: [fileURL],
                applicationActivities: nil
            )
            
            // For iPad support
            if let popoverController = activityViewController.popoverPresentationController {
                popoverController.sourceView = view
                popoverController.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
                popoverController.permittedArrowDirections = []
            }
            
            present(activityViewController, animated: true)
        } catch {
            print("Error saving report: \(error)")
            showAlert(message: "Failed to save the report.")
        }
    }

    
    // MARK: - Filter Input Methods
    private func showCustomerFilterInput() {
        let alertController = UIAlertController(title: "Filter by Customer", message: "Enter customer name", preferredStyle: .alert)
        
        alertController.addTextField { textField in
            textField.placeholder = "Customer name"
            
            // Pre-fill with existing filter value if any
            if let existingFilter = self.activeFilters.first(where: { $0.key == "customer" }) {
                textField.text = existingFilter.value
            }
        }
        
        alertController.addAction(UIAlertAction(title: "Apply Filter", style: .default) { [weak self] _ in
            guard let customerName = alertController.textFields?.first?.text, !customerName.isEmpty else { return }
            
            // Remove any existing customer filters
            self?.activeFilters.removeAll { $0.key == "customer" }
            
            // Add the new filter
            self?.activeFilters.append(Filter(key: "customer", value: customerName))
            self?.fetchInspections()
        })
        
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alertController, animated: true)
    }
    
    private func showDateFilterInput() {
        let alertController = UIAlertController(title: "Filter by Date", message: "Enter date (YYYY-MM-DD)", preferredStyle: .alert)
        
        alertController.addTextField { textField in
            textField.placeholder = "YYYY-MM-DD"
            
            // Pre-fill with existing filter value if any
            if let existingFilter = self.activeFilters.first(where: { $0.key == "date" }) {
                textField.text = existingFilter.value
            } else {
                // Default to today's date
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                textField.text = dateFormatter.string(from: Date())
            }
        }
        
        alertController.addAction(UIAlertAction(title: "Apply Filter", style: .default) { [weak self] _ in
            guard let dateString = alertController.textFields?.first?.text, !dateString.isEmpty else { return }
            
            // Validate date format
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            guard dateFormatter.date(from: dateString) != nil else {
                self?.showAlert(message: "Invalid date format. Please use YYYY-MM-DD.")
                return
            }
            
            // Remove any existing date filters
            self?.activeFilters.removeAll { $0.key == "date" }
            
            // Add the new filter
            self?.activeFilters.append(Filter(key: "date", value: dateString))
            self?.fetchInspections()
        })
        
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alertController, animated: true)
    }
    
    private func showInspectorFilterInput() {
        let alertController = UIAlertController(title: "Filter by Inspector", message: "Enter inspector name", preferredStyle: .alert)
        
        alertController.addTextField { textField in
            textField.placeholder = "Inspector name"
            
            // Pre-fill with existing filter value if any
            if let existingFilter = self.activeFilters.first(where: { $0.key == "inspector" }) {
                textField.text = existingFilter.value
            }
        }
        
        alertController.addAction(UIAlertAction(title: "Apply Filter", style: .default) { [weak self] _ in
            guard let inspectorName = alertController.textFields?.first?.text, !inspectorName.isEmpty else { return }
            
            // Remove any existing inspector filters
            self?.activeFilters.removeAll { $0.key == "inspector" }
            
            // Add the new filter
            self?.activeFilters.append(Filter(key: "inspector", value: inspectorName))
            self?.fetchInspections()
        })
        
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alertController, animated: true)
    }
    
    // MARK: - Helper Methods
    private func showAlert(message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource
extension ReportViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return inspections.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "InspectionCell", for: indexPath)
        let inspection = inspections[indexPath.row]
        
        // Configure cell
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        
        let dateString = inspection.date.map { dateFormatter.string(from: $0) } ?? "Unknown Date"
                cell.textLabel?.text = "Inspection on \(dateString)"

        let customerName = inspection.customer?.name ?? "Unknown Customer"
                cell.detailTextLabel?.text = "Customer: \(customerName)"
        
        // Show selection state
        if let selectedInspection = selectedInspection, selectedInspection == inspection {
            cell.accessoryType = .checkmark
        } else {
            cell.accessoryType = .none
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Select an inspection to generate a report"
    }
}

// MARK: - UITableViewDelegate
extension ReportViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        selectedInspection = inspections[indexPath.row]
        tableView.reloadData()
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
