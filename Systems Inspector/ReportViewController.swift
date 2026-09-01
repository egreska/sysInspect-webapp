//
//  ReportViewController.swift
//  Systems Inspector
//
//  Created by Eric Greska on 5/22/25.
import UIKit
import CoreData
import QuickLook
import MessageUI

class ReportViewController: UIViewController {
    
    // MARK: - Properties
    private let reportGenerator = ReportGenerator()
    private var inspections: [Inspection] = []
    private var selectedInspection: Inspection?
    /// Checkmarked inspections used for PDF and CSV export.
    private var selectedInspections: [Inspection] = []
    private var selectedSortCriteria: SortCriteria = .entryOrder
    private var activeFilters: [Filter] = []
    private var isLoadingInspections = false
    private static let skeletonRowCount = 6
    private lazy var progressOverlay = ReportProgressOverlay()
    private var currentPreviewURL: URL?
    
    // MARK: - UI Components
    private let tableView = UITableView()
    private let filterButton = UIButton(type: .system)
    private let sortButton = UIButton(type: .system)
    private let filterChipsScrollView = UIScrollView()
    private let filterChipsStack = UIStackView()
    private var filterChipsScrollViewHeightConstraint: NSLayoutConstraint?
    private let generatePDFButton = UIButton(type: .system)
    private let generateCSVButton = UIButton(type: .system)
    private lazy var reportsEmptyStateView: EmptyStateView = {
        let view = EmptyStateView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
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
        rebuildFilterChips()
        fetchInspections()
        setupAccessibilityOrder()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tabBarController?.viewControllers?[1].tabBarItem.badgeValue = nil
        fetchInspections()
    }
    
    private func setupAccessibilityOrder() {
        view.accessibilityElements = [filterButton, sortButton, filterChipsScrollView, tableView, generatePDFButton, generateCSVButton]
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        title = "Generate Reports"
        view.backgroundColor = AppTheme.background
        
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "InspectionCell")
        tableView.register(SkeletonCell.self, forCellReuseIdentifier: SkeletonCell.reuseId)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.tableFooterView = UIView()
        tableView.allowsMultipleSelection = true
        
        // Setup Filter Button
        filterButton.setTitle("Filter", for: .normal)
        filterButton.accessibilityLabel = "Filter"
        filterButton.addTarget(self, action: #selector(showFilterOptions), for: .touchUpInside)
        filterButton.translatesAutoresizingMaskIntoConstraints = false
        
        // Setup Sort Button
        sortButton.setTitle("Sort By: Entry Order", for: .normal)
        sortButton.accessibilityLabel = "Sort by"
        sortButton.addTarget(self, action: #selector(showSortOptions), for: .touchUpInside)
        sortButton.translatesAutoresizingMaskIntoConstraints = false
        
        // Setup Generate PDF Button
        generatePDFButton.setTitle("Generate PDF Report", for: .normal)
        generatePDFButton.accessibilityLabel = "Generate PDF report"
        generatePDFButton.addTarget(self, action: #selector(generatePDFReport), for: .touchUpInside)
        generatePDFButton.backgroundColor = AppTheme.primary
        generatePDFButton.setTitleColor(AppTheme.primaryContrast, for: .normal)
        generatePDFButton.layer.cornerRadius = 8
        generatePDFButton.translatesAutoresizingMaskIntoConstraints = false
        
        // Setup Generate CSV Button
        generateCSVButton.setTitle("Generate CSV Report", for: .normal)
        generateCSVButton.accessibilityLabel = "Generate CSV report"
        generateCSVButton.addTarget(self, action: #selector(generateCSVReport), for: .touchUpInside)
        generateCSVButton.backgroundColor = AppTheme.success
        generateCSVButton.setTitleColor(AppTheme.primaryContrast, for: .normal)
        generateCSVButton.layer.cornerRadius = 8
        generateCSVButton.translatesAutoresizingMaskIntoConstraints = false
        
        // Create button stack
        let buttonStack = UIStackView(arrangedSubviews: [generatePDFButton, generateCSVButton])
        buttonStack.axis = .horizontal
        buttonStack.spacing = 10
        buttonStack.distribution = .fillEqually
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        
        let filterSortStack = UIStackView(arrangedSubviews: [filterButton, sortButton])
        filterSortStack.axis = .horizontal
        filterSortStack.spacing = 10
        filterSortStack.distribution = .fillEqually
        filterSortStack.translatesAutoresizingMaskIntoConstraints = false
        
        filterChipsStack.axis = .horizontal
        filterChipsStack.spacing = 8
        filterChipsStack.alignment = .center
        filterChipsStack.translatesAutoresizingMaskIntoConstraints = false
        
        filterChipsScrollView.showsHorizontalScrollIndicator = false
        filterChipsScrollView.translatesAutoresizingMaskIntoConstraints = false
        filterChipsScrollView.addSubview(filterChipsStack)
        
        view.addSubview(filterSortStack)
        view.addSubview(filterChipsScrollView)
        view.addSubview(tableView)
        view.addSubview(buttonStack)
        
        filterChipsScrollViewHeightConstraint = filterChipsScrollView.heightAnchor.constraint(equalToConstant: 0)
        
        NSLayoutConstraint.activate([
            filterSortStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            filterSortStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            filterSortStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            filterChipsScrollView.topAnchor.constraint(equalTo: filterSortStack.bottomAnchor, constant: 4),
            filterChipsScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            filterChipsScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            filterChipsScrollViewHeightConstraint!,
            
            filterChipsStack.leadingAnchor.constraint(equalTo: filterChipsScrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            filterChipsStack.trailingAnchor.constraint(equalTo: filterChipsScrollView.contentLayoutGuide.trailingAnchor, constant: -16),
            filterChipsStack.topAnchor.constraint(equalTo: filterChipsScrollView.contentLayoutGuide.topAnchor),
            filterChipsStack.bottomAnchor.constraint(equalTo: filterChipsScrollView.contentLayoutGuide.bottomAnchor),
            filterChipsStack.heightAnchor.constraint(equalToConstant: 36),
            
            tableView.topAnchor.constraint(equalTo: filterChipsScrollView.bottomAnchor, constant: 4),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: buttonStack.topAnchor, constant: -16),
            
            buttonStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            buttonStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            buttonStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            buttonStack.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    private func updateEmptyState() {
        guard inspections.isEmpty else {
            tableView.backgroundView = nil
            return
        }
        let container = UIView(frame: tableView.bounds)
        container.backgroundColor = AppTheme.background
        container.addSubview(reportsEmptyStateView)
        NSLayoutConstraint.activate([
            reportsEmptyStateView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            reportsEmptyStateView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            reportsEmptyStateView.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 32),
            reportsEmptyStateView.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -32)
        ])
        if !activeFilters.isEmpty {
            reportsEmptyStateView.configure(
                symbolNames: ["line.3.horizontal.decrease.circle"],
                symbolPointSize: 52,
                title: "No inspections match your filters",
                message: "Clear filters to see all inspections, or add a new inspection from a customer.",
                buttonTitle: "Clear filters",
                buttonAction: { [weak self] in self?.clearFiltersTapped() }
            )
        } else {
            reportsEmptyStateView.configure(
                symbolNames: ["doc.text", "clipboard"],
                symbolPointSize: 48,
                title: "No inspections yet",
                message: "Add your first inspection from a customer to generate PDF or CSV reports.",
                buttonTitle: nil,
                buttonAction: nil
            )
        }
        tableView.backgroundView = container
    }
    
    @objc private func clearFiltersTapped() {
        activeFilters = []
        rebuildFilterChips()
        fetchInspections()
    }
    
    private func rebuildFilterChips() {
        filterChipsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let chipHeight: CGFloat = 32
        for (index, filter) in activeFilters.enumerated() {
            let label = displayLabel(for: filter)
            let keyLabel = filter.key.prefix(1).uppercased() + filter.key.dropFirst()
            let chip = FilterChipView(title: "\(keyLabel): \(label)")
            chip.onRemove = { [weak self] in
                self?.removeFilter(at: index)
            }
            chip.translatesAutoresizingMaskIntoConstraints = false
            filterChipsStack.addArrangedSubview(chip)
            chip.heightAnchor.constraint(equalToConstant: chipHeight).isActive = true
        }
        filterChipsScrollViewHeightConstraint?.constant = activeFilters.isEmpty ? 0 : 44
        filterChipsScrollView.isHidden = activeFilters.isEmpty
    }
    
    private func dateRangeDescriptionFromFilters() -> String? {
        guard let dateFilter = activeFilters.first(where: { $0.key == "date" }) else { return nil }
        return displayLabel(for: dateFilter)
    }
    
    private func displayLabel(for filter: Filter) -> String {
        switch filter.key {
        case "date":
            if filter.value == "7days" { return "Last 7 days" }
            if filter.value == "30days" { return "Last 30 days" }
            if filter.value.hasPrefix("custom:") {
                let parts = filter.value.split(separator: ":")
                if parts.count >= 3 { return "\(parts[1]) – \(parts[2])" }
            }
            return filter.value
        default:
            return filter.value
        }
    }
    
    private static func datePredicate(for value: String) -> NSPredicate? {
        let cal = Calendar.current
        let now = Date()
        switch value {
        case "7days":
            guard let start = cal.date(byAdding: .day, value: -7, to: now) else { return nil }
            return NSPredicate(format: "date >= %@ AND date <= %@", start as NSDate, now as NSDate)
        case "30days":
            guard let start = cal.date(byAdding: .day, value: -30, to: now) else { return nil }
            return NSPredicate(format: "date >= %@ AND date <= %@", start as NSDate, now as NSDate)
        case let v where v.hasPrefix("custom:"):
            let parts = v.split(separator: ":")
            guard parts.count >= 3 else { return nil }
            guard let start = DateFormatters.date(from: String(parts[1]), using: DateFormatters.isoDate),
                  let end = DateFormatters.date(from: String(parts[2]), using: DateFormatters.isoDate) else { return nil }
            let endOfDay = cal.date(byAdding: .day, value: 1, to: end) ?? end
            return NSPredicate(format: "date >= %@ AND date < %@", start as NSDate, endOfDay as NSDate)
        default:
            guard let date = DateFormatters.date(from: value, using: DateFormatters.isoDate) else { return nil }
            return NSPredicate(format: "date >= %@ AND date < %@",
                              date as NSDate,
                              date.addingTimeInterval(86400) as NSDate)
        }
    }
    
    private func removeFilter(at index: Int) {
        guard index < activeFilters.count else { return }
        activeFilters.remove(at: index)
        rebuildFilterChips()
        fetchInspections()
    }
    
    private func fetchInspections() {
        isLoadingInspections = true
        tableView.reloadData()
        
        let fetchRequest: NSFetchRequest<Inspection> = Inspection.fetchRequest()
        if !activeFilters.isEmpty {
            var predicates: [NSPredicate] = []
            for filter in activeFilters {
                switch filter.key {
                case "customer":
                    predicates.append(NSPredicate(format: "customer.name CONTAINS[cd] %@", filter.value))
                case "date":
                    if let pred = Self.datePredicate(for: filter.value) {
                        predicates.append(pred)
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
        switch selectedSortCriteria {
        case .date:
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        case .customer:
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "customer.name", ascending: true)]
        case .inspectionStatus:
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        case .importance, .primaryLocation, .issue, .entryOrder:
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        }
        
        CoreDataManager.shared.performBackgroundTask { [weak self] context in
            guard let self = self else { return }
            do {
                let result = try context.fetch(fetchRequest)
                let objectIDs = result.map(\.objectID)
                DispatchQueue.main.async {
                    let mainContext = CoreDataManager.shared.context
                    let mainResult = objectIDs.compactMap { try? mainContext.existingObject(with: $0) as? Inspection }
                    self.isLoadingInspections = false
                    self.inspections = mainResult
                    let resultIDs = Set(objectIDs)
                    if let selected = self.selectedInspection, !resultIDs.contains(selected.objectID) {
                        self.selectedInspection = nil
                    }
                    self.selectedInspections.removeAll { !resultIDs.contains($0.objectID) }
                    self.tableView.reloadSections(IndexSet(integer: 0), with: .automatic)
                    self.restoreTableSelection()
                    self.updateEmptyState()
                }
            } catch {
                DispatchQueue.main.async {
                    self.isLoadingInspections = false
                    self.tableView.reloadData()
                    #if DEBUG
                    print("Error fetching inspections: \(error)")
                    #endif
                }
            }
        }
    }
    
    /// Returns inspections without mutating Core Data. Item-level sort order is applied
    /// at report generation time via ReportGenerator.getSortedInspectionItems.
    private func sortInspectionItems(for inspections: [Inspection]) -> [Inspection] {
        // Do not mutate inspection.items - ReportGenerator sorts in memory for display
        return inspections
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
        
        let presets = FilterPresetStorage.load()
        if !presets.isEmpty {
            alertController.addAction(UIAlertAction(title: "Load preset…", style: .default) { [weak self] _ in
                self?.showPresetPicker(presets: presets)
            })
        }
        
        if !activeFilters.isEmpty {
            alertController.addAction(UIAlertAction(title: "Save this filter…", style: .default) { [weak self] _ in
                self?.showSavePresetPrompt()
            })
        }
        
        alertController.addAction(UIAlertAction(title: "Clear All Filters", style: .destructive) { [weak self] _ in
            self?.activeFilters = []
            self?.rebuildFilterChips()
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
        
        // MARK: - Report
        private func reportSelection() -> ReportFromInspections.Selection {
            ReportFromInspections.Selection(
                list: inspections,
                checked: selectedInspections,
                highlighted: selectedInspection
            )
        }

        @objc private func generatePDFReport() {
            let selection = reportSelection()
            guard !ReportFromInspections.inspections(for: selection, format: .pdf).isEmpty else {
                showAlert(message: "No inspection selected. Please select an inspection from the list.")
                return
            }
            guard ReportFromInspections.canJoin(selection) else {
                showAlert(message: CombinedPDFJoinRule.mixedSelectionMessage)
                return
            }
            let optionsVC = ReportPDFLayoutOptionsViewController()
            optionsVC.delegate = self
            let nav = UINavigationController(rootViewController: optionsVC)
            if let sheet = nav.sheetPresentationController {
                sheet.detents = [.medium(), .large()]
                sheet.prefersGrabberVisible = true
            }
            present(nav, animated: true)
        }

        private func generatePDFWithLayoutOptions(_ layoutOptions: PDFLayoutOptions) {
            let selection = reportSelection()
            guard !ReportFromInspections.inspections(for: selection, format: .pdf).isEmpty else {
                showAlert(message: "No inspection selected. Please select an inspection from the list.")
                return
            }
            progressOverlay.show(in: self, message: "Generating PDF…")
            generatePDFButton.isEnabled = false
            generateCSVButton.isEnabled = false
            ReportFromInspections.run(
                selection,
                format: .pdf,
                sortCriteria: selectedSortCriteria,
                layoutOptions: layoutOptions,
                dateRangeDescription: dateRangeDescriptionFromFilters(),
                header: ReportHeader.fromUserDefaults(),
                generator: reportGenerator
            ) { [weak self] result in
                guard let self else { return }
                self.finishExport(result: result) { package in
                    self.saveAndSharePDFReport(package)
                }
            }
        }

        @objc private func generateCSVReport() {
            let selection = reportSelection()
            let toExport = ReportFromInspections.inspections(for: selection, format: .csv)
            guard !toExport.isEmpty else {
                showAlert(message: "No inspections available to generate a report.")
                return
            }
            progressOverlay.show(in: self, message: "Generating CSV…")
            generatePDFButton.isEnabled = false
            generateCSVButton.isEnabled = false
            ReportFromInspections.run(
                selection,
                format: .csv,
                sortCriteria: selectedSortCriteria,
                dateRangeDescription: dateRangeDescriptionFromFilters(),
                header: ReportHeader.fromUserDefaults(),
                generator: reportGenerator
            ) { [weak self] result in
                guard let self else { return }
                self.finishExport(result: result) { package in
                    self.saveAndShareReportPackage(package, inspectionCount: toExport.count)
                }
            }
        }
    
    private func finishExport(result: ReportExportResult, onPackage: ((ReportPackage) -> Void)? = nil) {
        progressOverlay.hide()
        generatePDFButton.isEnabled = true
        generateCSVButton.isEnabled = true
        switch result {
        case .package(let package):
            onPackage?(package)
        case .joinFailed:
            showAlert(message: CombinedPDFJoinRule.mixedSelectionMessage)
        case .empty, .failed:
            showAlert(message: "We couldn't generate the report. Please try again.")
        }
    }
    
    // New method to handle report package sharing
    private func saveAndShareReportPackage(_ reportPackage: ReportPackage, inspectionCount: Int = 0) {
        let tempDirectory = FileManager.default.temporaryDirectory
        let csvURL = tempDirectory.appendingPathComponent(reportPackage.fileName)
        
        var itemsToShare: [Any] = []
        
        do {
            try reportPackage.data.write(to: csvURL)
            itemsToShare.append(csvURL)
            
            if let zipData = reportPackage.companionData, let zipName = reportPackage.companionFileName {
                let zipURL = tempDirectory.appendingPathComponent(zipName)
                try zipData.write(to: zipURL)
                itemsToShare.append(zipURL)
            }
            
            let summary = "Systems Inspector Report – \(inspectionCount) inspection\(inspectionCount == 1 ? "" : "s"). Generated \(DateFormatters.format(Date(), using: DateFormatters.mediumDateTime))."
            itemsToShare.append(summary)
            
            let customActivities: [UIActivity] = [
                CopySummaryActivity(),
                EmailReportActivity(presenter: self)
            ]
            
            HapticManager.success()
            ToastView.show(on: self, message: "Report ready", duration: 2.0)
            
            // Present activity controller with both files
            let activityViewController = UIActivityViewController(
                activityItems: itemsToShare,
                applicationActivities: customActivities
            )
            
            // Customize the activity controller
            activityViewController.setValue("Systems Inspector Report", forKey: "subject")
            
            // For iPad support
            if let popoverController = activityViewController.popoverPresentationController {
                popoverController.sourceView = view
                popoverController.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
                popoverController.permittedArrowDirections = []
            }
            
            present(activityViewController, animated: true)
            
        } catch {
            #if DEBUG
            print("Error saving report package: \(error)")
            #endif
            showAlert(message: "We couldn't save the report files. Please try again.")
        }
    }

    private func saveAndSharePDFReport(_ package: ReportPackage) {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(package.fileName)
        do {
            try package.data.write(to: fileURL)
            currentPreviewURL = fileURL
            HapticManager.success()
            ToastView.show(on: self, message: "Report ready", duration: 2.0)
            let ql = QLPreviewController()
            ql.dataSource = self
            present(ql, animated: true)
        } catch {
            #if DEBUG
            print("Error saving report: \(error)")
            #endif
            showAlert(message: "We couldn't save the report. Please try again.")
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
            self?.rebuildFilterChips()
            self?.fetchInspections()
        })
        
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alertController, animated: true)
    }
    
    private func showDateFilterInput() {
        let alert = UIAlertController(title: "Filter by Date", message: "Choose date range", preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Last 7 days", style: .default) { [weak self] _ in
            self?.applyDateFilter(value: "7days")
        })
        alert.addAction(UIAlertAction(title: "Last 30 days", style: .default) { [weak self] _ in
            self?.applyDateFilter(value: "30days")
        })
        alert.addAction(UIAlertAction(title: "Custom range…", style: .default) { [weak self] _ in
            self?.showCustomDateRangeInput()
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let popover = alert.popoverPresentationController {
            popover.sourceView = filterButton
            popover.sourceRect = filterButton.bounds
        }
        present(alert, animated: true)
    }
    
    private func showCustomDateRangeInput() {
        let alert = UIAlertController(title: "Custom Date Range", message: "Enter start and end dates (YYYY-MM-DD)", preferredStyle: .alert)
        
        alert.addTextField { field in
            field.placeholder = "Start date (YYYY-MM-DD)"
            if let existing = self.activeFilters.first(where: { $0.key == "date" && $0.value.hasPrefix("custom:") }) {
                let parts = existing.value.split(separator: ":")
                if parts.count >= 2 { field.text = String(parts[1]) }
            }
        }
        alert.addTextField { field in
            field.placeholder = "End date (YYYY-MM-DD)"
            if let existing = self.activeFilters.first(where: { $0.key == "date" && $0.value.hasPrefix("custom:") }) {
                let parts = existing.value.split(separator: ":")
                if parts.count >= 3 { field.text = String(parts[2]) }
            }
        }
        
        alert.addAction(UIAlertAction(title: "Apply", style: .default) { [weak self] _ in
            guard let startStr = alert.textFields?[0].text, !startStr.isEmpty,
                  let endStr = alert.textFields?[1].text, !endStr.isEmpty else { return }
            guard let start = DateFormatters.date(from: startStr, using: DateFormatters.isoDate),
                  let end = DateFormatters.date(from: endStr, using: DateFormatters.isoDate),
                  start <= end else {
                self?.showAlert(message: "Invalid dates. Use YYYY-MM-DD and ensure start ≤ end.")
                return
            }
            let value = "custom:\(startStr):\(endStr)"
            self?.applyDateFilter(value: value)
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    private func showSavePresetPrompt() {
        let alert = UIAlertController(title: "Save Filter Preset", message: "Enter a name for this filter", preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "e.g. Monthly Acme" }
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            guard let name = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else { return }
            let preset = FilterPreset(name: name, filters: self?.activeFilters ?? [])
            FilterPresetStorage.add(preset)
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    private func showPresetPicker(presets: [FilterPreset]) {
        let alert = UIAlertController(title: "Load Preset", message: nil, preferredStyle: .actionSheet)
        for preset in presets {
            alert.addAction(UIAlertAction(title: preset.name, style: .default) { [weak self] _ in
                self?.activeFilters = preset.filters
                self?.rebuildFilterChips()
                self?.fetchInspections()
            })
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let popover = alert.popoverPresentationController {
            popover.sourceView = filterButton
            popover.sourceRect = filterButton.bounds
        }
        present(alert, animated: true)
    }
    
    private func applyDateFilter(value: String) {
        activeFilters.removeAll { $0.key == "date" }
        activeFilters.append(Filter(key: "date", value: value))
        rebuildFilterChips()
        fetchInspections()
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
            self?.rebuildFilterChips()
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
        if isLoadingInspections && inspections.isEmpty { return Self.skeletonRowCount }
        return inspections.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if isLoadingInspections && inspections.isEmpty {
            return tableView.dequeueReusableCell(withIdentifier: SkeletonCell.reuseId, for: indexPath)
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: "InspectionCell", for: indexPath)
        let inspection = inspections[indexPath.row]
        
        // Configure cell
        let dateString = inspection.date.map { DateFormatters.format($0, using: DateFormatters.mediumDateTime) } ?? "Unknown Date"
                cell.textLabel?.text = "Inspection on \(dateString)"

        let customerName = inspection.customer?.name ?? "Unknown Customer"
                cell.detailTextLabel?.text = "Customer: \(customerName)"
        
        cell.accessoryType = selectedInspections.contains(where: { $0.objectID == inspection.objectID }) ? .checkmark : .none
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Select inspection(s) for reports"
    }
}

// MARK: - UITableViewDelegate
extension ReportViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard !isLoadingInspections, indexPath.row < inspections.count else {
            tableView.deselectRow(at: indexPath, animated: true)
            return
        }
        let inspection = inspections[indexPath.row]
        selectedInspection = inspection
        if let idx = selectedInspections.firstIndex(where: { $0.objectID == inspection.objectID }) {
            selectedInspections.remove(at: idx)
        } else {
            selectedInspections.append(inspection)
        }
        reloadAndRestoreSelection()
    }
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        guard !isLoadingInspections, indexPath.row < inspections.count else { return }
        let inspection = inspections[indexPath.row]
        selectedInspections.removeAll { $0.objectID == inspection.objectID }
        reloadAndRestoreSelection()
    }
    
    private func reloadAndRestoreSelection() {
        tableView.reloadData()
        restoreTableSelection()
    }
    
    private func restoreTableSelection() {
        let selectedIDs = Set(selectedInspections.map(\.objectID))
        for (index, inspection) in inspections.enumerated() {
            if selectedIDs.contains(inspection.objectID) {
                tableView.selectRow(at: IndexPath(row: index, section: 0), animated: false, scrollPosition: .none)
            }
        }
    }
}

// MARK: - ReportPDFLayoutOptionsDelegate
extension ReportViewController: ReportPDFLayoutOptionsDelegate {
    func reportPDFLayoutOptions(_ controller: ReportPDFLayoutOptionsViewController, didChoose options: PDFLayoutOptions) {
        generatePDFWithLayoutOptions(options)
    }
}

// MARK: - QLPreviewControllerDataSource
extension ReportViewController: QLPreviewControllerDataSource {
    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        currentPreviewURL != nil ? 1 : 0
    }
    
    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        (currentPreviewURL ?? URL(fileURLWithPath: "")) as QLPreviewItem
    }
}
