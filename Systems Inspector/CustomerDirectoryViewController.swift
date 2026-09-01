//
//  CustomerDirectoryViewController.swift
//  Systems Inspector
//
//  Created by Eric Greska on 5/22/25.
//
import UIKit
import Combine

class CustomerDirectoryViewController: UIViewController {
    // MARK: - Properties
    private var tableView: UITableView!
    private let searchController = UISearchController(searchResultsController: nil)
    private var viewModel = CustomerDirectoryViewModel()
    private var cancellables = Set<AnyCancellable>()
    private let refreshControl = UIRefreshControl()
    private var deletingIndexPath: IndexPath?
    private var pendingDeletedCustomer: Customer?
    private var deleteUndoTimer: Timer?
    private lazy var emptyStateView: EmptyStateView = {
        let view = EmptyStateView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupBindings()
        viewModel.fetchCustomers()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if viewModel.customers.isEmpty && !viewModel.isLoading {
            viewModel.fetchCustomers()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: .cloudKitSyncStatusChanged, object: nil)
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        title = "Customers"
        view.backgroundColor = AppTheme.background
        
        // Setup TableView
        tableView = UITableView(frame: view.bounds, style: .plain)
        tableView.register(CustomerCell.self, forCellReuseIdentifier: "CustomerCell")
        tableView.register(LoadingCell.self, forCellReuseIdentifier: "LoadingCell")
        tableView.register(SkeletonCell.self, forCellReuseIdentifier: SkeletonCell.reuseId)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.prefetchDataSource = self
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.tableFooterView = UIView() // Remove empty cell separators
        
        // Add refresh control
        refreshControl.addTarget(self, action: #selector(refreshData), for: .valueChanged)
        tableView.refreshControl = refreshControl
        
        view.addSubview(tableView)
        
        // Setup Search Controller
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search Customers"
        searchController.searchBar.tintColor = .systemBlue
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        definesPresentationContext = true
        
        // Add Customer Button
        let addButton = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(addCustomerTapped)
        )
        addButton.accessibilityLabel = "Add customer"
        navigationItem.rightBarButtonItem = addButton
        
        // Layout Constraints
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func setupBindings() {
        viewModel.$customers
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.tableView.reloadData()
                self?.refreshControl.endRefreshing()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(cloudKitSyncStatusChanged),
            name: .cloudKitSyncStatusChanged,
            object: nil
        )
        
        viewModel.$isLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.tableView.reloadData()
            }
            .store(in: &cancellables)
        
        viewModel.$hasMoreCustomers
            .receive(on: DispatchQueue.main)
            .sink { hasMore in
                #if DEBUG
                print("📊 Has more customers: \(hasMore)")
                #endif
            }
            .store(in: &cancellables)
        
        viewModel.$errorMessage
            .compactMap { $0 }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                self?.showErrorAlert(message: message)
            }
            .store(in: &cancellables)
    }
    
    /// Returns true if the customer should show "Pending sync" badge (created recently while sync failed).
    private func shouldShowPendingSyncBadge(for customer: Customer) -> Bool {
        let status = CoreDataManager.shared.currentCloudKitSyncStatus
        guard case .failed = status else { return false }
        guard let created = customer.createdDate else { return false }
        return Date().timeIntervalSince(created) <= pendingSyncTimeWindow
    }
    
    @objc private func cloudKitSyncStatusChanged() {
        tableView.reloadData()
    }
    
    private func showErrorAlert(message: String) {
        let alert = UIAlertController(
            title: "Error",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.viewModel.clearError()
        })
        present(alert, animated: true)
    }
    
    // MARK: - Actions
    @objc private func addCustomerTapped() {
        let formVC = CustomerFormViewController()
        formVC.delegate = self
        let navController = UINavigationController(rootViewController: formVC)
        if let sheet = navController.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
        present(navController, animated: true)
    }
    
    @objc private func refreshData() {
        viewModel.fetchCustomers()
    }
    
    private func showDeleteFailedAlert() {
        let alert = UIAlertController(
            title: "Delete Failed",
            message: "We couldn't delete the customer. Please try again.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private static let skeletonRowCount = 8
}

// MARK: - UITableViewDataSource
extension CustomerDirectoryViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let count = viewModel.customers.count
        
        if viewModel.isLoading && count == 0 {
            tableView.backgroundView = nil
            return Self.skeletonRowCount
        }
        
        if count == 0 {
            let isSearching = searchController.isActive && !(searchController.searchBar.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let container = UIView(frame: CGRect(x: 0, y: 0, width: tableView.bounds.width, height: max(tableView.bounds.height, 320)))
            container.backgroundColor = AppTheme.background
            container.addSubview(emptyStateView)
            NSLayoutConstraint.activate([
                emptyStateView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                emptyStateView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                emptyStateView.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 32),
                emptyStateView.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -32)
            ])
            if isSearching {
                let query = searchController.searchBar.text ?? ""
                emptyStateView.configure(
                    symbolNames: ["magnifyingglass"],
                    title: "No matches",
                    message: "No customers match \"\(query)\". Try a different search or add a new customer.",
                    buttonTitle: "Add customer",
                    buttonAction: { [weak self] in
                        self?.searchController.isActive = false
                        self?.addCustomerTapped()
                    }
                )
            } else {
                emptyStateView.configure(
                    symbolNames: ["person.3", "plus.circle"],
                    symbolPointSize: 48,
                    title: "No customers yet",
                    message: "Add your first customer to start tracking inspections.",
                    buttonTitle: "Add customer",
                    buttonAction: { [weak self] in self?.addCustomerTapped() }
                )
            }
            tableView.backgroundView = container
        } else {
            tableView.backgroundView = nil
        }
        
        if count == 0 { return count }
        return viewModel.hasMoreCustomers ? count + 1 : count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if viewModel.isLoading && viewModel.customers.isEmpty {
            return tableView.dequeueReusableCell(withIdentifier: SkeletonCell.reuseId, for: indexPath)
        }
        if deletingIndexPath == indexPath {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "LoadingCell", for: indexPath) as? LoadingCell else {
                return UITableViewCell()
            }
            cell.setLoadingText("Deleting…")
            cell.startAnimating()
            return cell
        }
        if indexPath.row == viewModel.customers.count && viewModel.hasMoreCustomers {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "LoadingCell", for: indexPath) as? LoadingCell else {
                return UITableViewCell()
            }
            cell.setLoadingText("Loading more customers...")
            cell.startAnimating()
            return cell
        }
        
        guard indexPath.row < viewModel.customers.count else {
            return UITableViewCell()
        }
        
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "CustomerCell", for: indexPath) as? CustomerCell else {
            return UITableViewCell()
        }
        let customer = viewModel.customers[indexPath.row]
        let showPendingSync = shouldShowPendingSyncBadge(for: customer)
        cell.configure(with: customer, showPendingSync: showPendingSync)
        return cell
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
            guard !viewModel.isLoading, indexPath.row < viewModel.customers.count else { return }
            if editingStyle == .delete {
                let customer = viewModel.customers[indexPath.row]

                // Safely unwrap customer.name for the alert message
                let customerName = customer.name ?? "this customer" // Provide a default if name is nil

                let alert = UIAlertController(
                    title: "Delete Customer",
                    message: "Are you sure you want to delete \(customerName)? This will also delete all associated inspections.",
                    preferredStyle: .alert
                )

                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

                alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
                    guard let self = self else { return }
                    guard indexPath.row < self.viewModel.customers.count else { return }
                    self.deletingIndexPath = nil
                    let customer = self.viewModel.customers[indexPath.row]
                    // Ensure object is fully loaded before removing from array
                    _ = customer.objectID
                    guard let removedCustomer = self.viewModel.removeCustomerFromList(at: indexPath.row) else { return }
                    self.pendingDeletedCustomer = removedCustomer
                    self.tableView.performBatchUpdates({
                        self.tableView.deleteRows(at: [indexPath], with: .automatic)
                    }, completion: nil)
                    HapticManager.success()
                    self.deleteUndoTimer?.invalidate()
                    self.deleteUndoTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
                        self?.commitPendingDelete()
                    }
                    ToastView.show(
                        on: self,
                        message: "Customer removed",
                        actionTitle: "Undo",
                        action: { [weak self] in
                            self?.undoDelete(customer: removedCustomer)
                        },
                        duration: 5.0
                    )
                })

                present(alert, animated: true)
            }
        }
}

// MARK: - UITableViewDelegate
extension CustomerDirectoryViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard !viewModel.isLoading, !viewModel.customers.isEmpty, indexPath.row < viewModel.customers.count else {
            tableView.deselectRow(at: indexPath, animated: true)
            return
        }
        
        let customer = viewModel.customers[indexPath.row]
        let customerDetailsVC = CustomerDetailsViewController(customer: customer)
        navigationController?.pushViewController(customerDetailsVC, animated: true)
        
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard !viewModel.isLoading, indexPath.row < viewModel.customers.count else { return nil }
        let customer = viewModel.customers[indexPath.row]
        
        let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, completion in
            guard let self = self else { completion(false); return }
            let customerName = customer.name ?? "this customer"
            let alert = UIAlertController(
                title: "Delete Customer",
                message: "Are you sure you want to delete \(customerName)? This will also delete all associated inspections.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completion(false) })
            alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
                guard let self = self else { completion(false); return }
                guard indexPath.row < self.viewModel.customers.count else { completion(false); return }
                self.deletingIndexPath = nil
                let customer = self.viewModel.customers[indexPath.row]
                _ = customer.objectID
                guard let removedCustomer = self.viewModel.removeCustomerFromList(at: indexPath.row) else {
                    completion(false); return
                }
                self.pendingDeletedCustomer = removedCustomer
                self.tableView.performBatchUpdates({
                    self.tableView.deleteRows(at: [indexPath], with: .automatic)
                }, completion: nil)
                HapticManager.success()
                self.deleteUndoTimer?.invalidate()
                self.deleteUndoTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
                    self?.commitPendingDelete()
                }
                ToastView.show(on: self, message: "Customer removed", actionTitle: "Undo", action: { [weak self] in
                    self?.undoDelete(customer: removedCustomer)
                }, duration: 5.0)
                completion(true)
            })
            self.present(alert, animated: true)
        }
        deleteAction.image = UIImage(systemName: "trash")
        
        let editAction = UIContextualAction(style: .normal, title: "Edit") { [weak self] _, _, completion in
            guard let self = self else { completion(false); return }
            let formVC = CustomerFormViewController(customer: customer)
            formVC.delegate = self
            let nav = UINavigationController(rootViewController: formVC)
            if let sheet = nav.sheetPresentationController {
                sheet.detents = [.large()]
                sheet.prefersGrabberVisible = true
            }
            self.present(nav, animated: true)
            completion(true)
        }
        editAction.image = UIImage(systemName: "pencil")
        editAction.backgroundColor = .systemBlue
        
        return UISwipeActionsConfiguration(actions: [deleteAction, editAction])
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if viewModel.isLoading && viewModel.customers.isEmpty { return 80 }
        if indexPath.row == viewModel.customers.count && viewModel.hasMoreCustomers {
            return 60
        }
        
        guard indexPath.row < viewModel.customers.count else {
            return 80
        }
        
        let customer = viewModel.customers[indexPath.row]
        guard let customerId = customer.id?.uuidString else {
            return 80
        }
        
        return PerformanceOptimizer.shared.getCellHeight(for: customerId) {
            return 80 // Standard customer cell height
        }
    }
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        if viewModel.isLoading && viewModel.customers.isEmpty { return 80 }
        if indexPath.row == viewModel.customers.count && viewModel.hasMoreCustomers { return 60 }
        return 80
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if viewModel.isLoading && viewModel.customers.isEmpty { return }
        guard indexPath.row < viewModel.customers.count || (indexPath.row == viewModel.customers.count && viewModel.hasMoreCustomers) else { return }
        if viewModel.shouldLoadMore(currentIndex: indexPath.row) {
            #if DEBUG
            print("📄 Loading more customers...")
            #endif
            viewModel.fetchNextPage()
        }
    }
}

// MARK: - UITableViewDataSourcePrefetching
extension CustomerDirectoryViewController: UITableViewDataSourcePrefetching {
    func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath]) {
        if viewModel.isLoading && viewModel.customers.isEmpty { return }
        for indexPath in indexPaths {
            guard indexPath.row < viewModel.customers.count || (indexPath.row == viewModel.customers.count && viewModel.hasMoreCustomers) else { continue }
            if viewModel.shouldLoadMore(currentIndex: indexPath.row) {
                #if DEBUG
                print("🔄 Prefetching more customers...")
                #endif
                viewModel.fetchNextPage()
                break
            }
        }
    }
}

// MARK: - UISearchResultsUpdating
extension CustomerDirectoryViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        guard let searchText = searchController.searchBar.text else { return }
        viewModel.filterCustomers(searchText: searchText)
    }
}

// MARK: - CustomerFormDelegate
extension CustomerDirectoryViewController: CustomerFormDelegate {
    func didSaveCustomer(_ customer: Customer, isNew: Bool) {
        viewModel.fetchCustomers()
        guard isNew else { return }
        let customerDetailsVC = CustomerDetailsViewController(customer: customer)
        navigationController?.pushViewController(customerDetailsVC, animated: true)
        ToastView.show(on: customerDetailsVC, message: "Customer added")
    }
}

// MARK: - Delete undo
extension CustomerDirectoryViewController {
    private func undoDelete(customer: Customer) {
        deleteUndoTimer?.invalidate()
        deleteUndoTimer = nil
        pendingDeletedCustomer = nil
        let oldCount = viewModel.customers.count
        viewModel.restoreCustomer(customer)
        let newCount = viewModel.customers.count
        if newCount > oldCount {
            // Customer was restored, reload to show it
            tableView.reloadData()
        }
    }
    
    private func commitPendingDelete() {
        deleteUndoTimer?.invalidate()
        deleteUndoTimer = nil
        guard let customer = pendingDeletedCustomer else { return }
        pendingDeletedCustomer = nil
        viewModel.confirmDeleteCustomer(customer) { [weak self] success in
            DispatchQueue.main.async {
                if !success {
                    self?.showDeleteFailedAlert()
                    self?.viewModel.fetchCustomers()
                }
                // Reload to ensure table view is in sync
                self?.tableView.reloadData()
            }
        }
    }
}

// MARK: - Loading Cell for Pagination
class LoadingCell: UITableViewCell {
    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.hidesWhenStopped = false
        return indicator
    }()
    
    private let loadingLabel: UILabel = {
        let label = UILabel()
        label.text = "Loading more customers..."
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        selectionStyle = .none
        contentView.addSubview(activityIndicator)
        contentView.addSubview(loadingLabel)
        
        NSLayoutConstraint.activate([
            activityIndicator.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            activityIndicator.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            
            loadingLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            loadingLabel.leadingAnchor.constraint(equalTo: activityIndicator.trailingAnchor, constant: 12),
            loadingLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        ])
    }
    
    func startAnimating() {
        activityIndicator.startAnimating()
    }
    
    func stopAnimating() {
        activityIndicator.stopAnimating()
    }
    
    func setLoadingText(_ text: String) {
        loadingLabel.text = text
    }
}

/// Time window for showing "Pending sync" badge (items created within this period while sync failed)
private let pendingSyncTimeWindow: TimeInterval = 24 * 60 * 60

// MARK: - Custom Cell for Customers
class CustomerCell: UITableViewCell {
    private let companyNameLabel = UILabel()
    private let siteLabel = UILabel()
    private let contactNameLabel = UILabel()
    private let inspectionCountLabel = UILabel()
    private let dateLabel = UILabel()
    private let pendingSyncBadge: UILabel = {
        let label = UILabel()
        label.text = "Pending sync"
        label.font = .preferredFont(forTextStyle: .caption2)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .systemOrange
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        accessoryType = .disclosureIndicator
        
        // Configure labels (Dynamic Type)
        companyNameLabel.font = .preferredFont(forTextStyle: .headline)
        companyNameLabel.adjustsFontForContentSizeCategory = true
        companyNameLabel.translatesAutoresizingMaskIntoConstraints = false
        
        siteLabel.font = .preferredFont(forTextStyle: .subheadline)
        siteLabel.adjustsFontForContentSizeCategory = true
        siteLabel.textColor = AppTheme.textSecondary
        siteLabel.translatesAutoresizingMaskIntoConstraints = false
        
        contactNameLabel.font = .preferredFont(forTextStyle: .subheadline)
        contactNameLabel.adjustsFontForContentSizeCategory = true
        contactNameLabel.textColor = AppTheme.textSecondary
        contactNameLabel.translatesAutoresizingMaskIntoConstraints = false
        
        inspectionCountLabel.font = .preferredFont(forTextStyle: .caption1)
        inspectionCountLabel.adjustsFontForContentSizeCategory = true
        inspectionCountLabel.textColor = .systemBlue
        inspectionCountLabel.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.addSubview(pendingSyncBadge)
        
        dateLabel.font = .preferredFont(forTextStyle: .caption1)
        dateLabel.adjustsFontForContentSizeCategory = true
        dateLabel.textColor = AppTheme.textTertiary
        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Add labels to content view
        contentView.addSubview(companyNameLabel)
        contentView.addSubview(siteLabel)
        contentView.addSubview(contactNameLabel)
        contentView.addSubview(inspectionCountLabel)
        contentView.addSubview(dateLabel)
        
        // Layout constraints
        NSLayoutConstraint.activate([
            companyNameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            companyNameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            companyNameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -40),
            
            siteLabel.topAnchor.constraint(equalTo: companyNameLabel.bottomAnchor, constant: 2),
            siteLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            siteLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -40),
            
            contactNameLabel.topAnchor.constraint(equalTo: siteLabel.bottomAnchor, constant: 2),
            contactNameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            
            inspectionCountLabel.topAnchor.constraint(equalTo: contactNameLabel.bottomAnchor, constant: 4),
            inspectionCountLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            inspectionCountLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            
            dateLabel.centerYAnchor.constraint(equalTo: inspectionCountLabel.centerYAnchor),
            dateLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -40),
            
            pendingSyncBadge.centerYAnchor.constraint(equalTo: inspectionCountLabel.centerYAnchor),
            pendingSyncBadge.leadingAnchor.constraint(equalTo: inspectionCountLabel.trailingAnchor, constant: 8),
            pendingSyncBadge.trailingAnchor.constraint(lessThanOrEqualTo: dateLabel.leadingAnchor, constant: -8)
        ])
    }
    
    func configure(with customer: Customer, showPendingSync: Bool = false) {
        companyNameLabel.text = customer.name ?? "Unknown Company"
        
        // Show site if available
        if let site = customer.site, !site.isEmpty {
            siteLabel.text = "Site: \(site)"
            siteLabel.isHidden = false
        } else {
            siteLabel.isHidden = true
        }
        
        // Show contact name if available
        if let contactName = customer.contactName, !contactName.isEmpty {
            contactNameLabel.text = "Contact: \(contactName)"
            contactNameLabel.isHidden = false
        } else {
            contactNameLabel.isHidden = true
        }
        
        let inspectionCount = customer.inspections?.count ?? 0
        inspectionCountLabel.text = "\(inspectionCount) inspection\(inspectionCount == 1 ? "" : "s")"

        let dateString = DateFormatters.format(customer.createdDate ?? Date(), using: DateFormatters.short)
        dateLabel.text = "Added: \(dateString)"
        
        pendingSyncBadge.isHidden = !showPendingSync
        
        let name = customer.name ?? "Unknown Company"
        var a11y = "Customer, \(name), \(inspectionCount) inspection\(inspectionCount == 1 ? "" : "s")"
        if showPendingSync { a11y += ", pending sync" }
        accessibilityLabel = a11y
        accessibilityHint = "Double tap to view details"
    }
}

