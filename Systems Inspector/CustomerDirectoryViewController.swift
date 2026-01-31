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
    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupBindings()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel.fetchCustomers()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        title = "Customers"
        view.backgroundColor = .white
        
        // Setup TableView
        tableView = UITableView(frame: view.bounds, style: .plain)
        tableView.register(CustomerCell.self, forCellReuseIdentifier: "CustomerCell")
        tableView.register(LoadingCell.self, forCellReuseIdentifier: "LoadingCell")
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
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(addCustomerTapped)
        )
        
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
        
        viewModel.$hasMoreCustomers
            .receive(on: DispatchQueue.main)
            .sink { hasMore in
                print("📊 Has more customers: \(hasMore)")
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Actions
    @objc private func addCustomerTapped() {
        let addCustomerVC = AddCustomerViewController()
        addCustomerVC.delegate = self
        let navController = UINavigationController(rootViewController: addCustomerVC)
        present(navController, animated: true)
    }
    
    @objc private func refreshData() {
        viewModel.fetchCustomers()
    }
}

// MARK: - UITableViewDataSource
extension CustomerDirectoryViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let count = viewModel.customers.count
        
        // Show empty state if no customers
        if count == 0 {
            let emptyLabel = UILabel(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 200))
            emptyLabel.text = "No customers found.\nTap + to add a new customer."
            emptyLabel.textAlignment = .center
            emptyLabel.textColor = .darkGray
            emptyLabel.numberOfLines = 2
            tableView.backgroundView = emptyLabel
        } else {
            tableView.backgroundView = nil
        }
        
        // Add 1 for loading cell if has more
        return viewModel.hasMoreCustomers ? count + 1 : count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // Check if this is the loading cell
        if indexPath.row == viewModel.customers.count && viewModel.hasMoreCustomers {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "LoadingCell", for: indexPath) as? LoadingCell else {
                return UITableViewCell()
            }
            cell.startAnimating()
            return cell
        }
        
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "CustomerCell", for: indexPath) as? CustomerCell else {
            return UITableViewCell()
        }
        
        let customer = viewModel.customers[indexPath.row]
        cell.configure(with: customer)
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
            if editingStyle == .delete {
                // Show confirmation alert
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
                    self?.viewModel.deleteCustomer(at: indexPath.row)
                })

                present(alert, animated: true)
            }
        }
}

// MARK: - UITableViewDelegate
extension CustomerDirectoryViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // Don't allow selection of loading cell
        guard indexPath.row < viewModel.customers.count else {
            tableView.deselectRow(at: indexPath, animated: true)
            return
        }
        
        let customer = viewModel.customers[indexPath.row]
        let customerDetailsVC = CustomerDetailsViewController(customer: customer)
        navigationController?.pushViewController(customerDetailsVC, animated: true)
        
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        // Loading cell height
        if indexPath.row == viewModel.customers.count && viewModel.hasMoreCustomers {
            return 60
        }
        
        // Use cached height for better performance
        let customer = viewModel.customers[indexPath.row]
        guard let customerId = customer.id?.uuidString else {
            return 80
        }
        
        return PerformanceOptimizer.shared.getCellHeight(for: customerId) {
            return 80 // Standard customer cell height
        }
    }
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        // Provide estimated height for better scrolling performance
        if indexPath.row == viewModel.customers.count && viewModel.hasMoreCustomers {
            return 60
        }
        return 80
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        // Check if should load more
        if viewModel.shouldLoadMore(currentIndex: indexPath.row) {
            print("📄 Loading more customers...")
            viewModel.fetchNextPage()
        }
    }
}

// MARK: - UITableViewDataSourcePrefetching
extension CustomerDirectoryViewController: UITableViewDataSourcePrefetching {
    func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath]) {
        // Prefetch next page when approaching the end
        for indexPath in indexPaths {
            if viewModel.shouldLoadMore(currentIndex: indexPath.row) {
                print("🔄 Prefetching more customers...")
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

// MARK: - AddCustomerViewControllerDelegate
extension CustomerDirectoryViewController: AddCustomerViewControllerDelegate {
    func didAddCustomer(_ customer: Customer) {
        viewModel.fetchCustomers()
        
        // Optionally navigate to the new customer details
        let customerDetailsVC = CustomerDetailsViewController(customer: customer)
        navigationController?.pushViewController(customerDetailsVC, animated: true)
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
        label.font = UIFont.systemFont(ofSize: 14)
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
}

// MARK: - Custom Cell for Customers
class CustomerCell: UITableViewCell {
    private let companyNameLabel = UILabel()
    private let siteLabel = UILabel()
    private let contactNameLabel = UILabel()
    private let inspectionCountLabel = UILabel()
    private let dateLabel = UILabel()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        accessoryType = .disclosureIndicator
        
        // Configure labels
        companyNameLabel.font = UIFont.boldSystemFont(ofSize: 16)
        companyNameLabel.translatesAutoresizingMaskIntoConstraints = false
        
        siteLabel.font = UIFont.systemFont(ofSize: 14)
        siteLabel.textColor = .darkGray
        siteLabel.translatesAutoresizingMaskIntoConstraints = false
        
        contactNameLabel.font = UIFont.systemFont(ofSize: 14)
        contactNameLabel.textColor = .darkGray
        contactNameLabel.translatesAutoresizingMaskIntoConstraints = false
        
        inspectionCountLabel.font = UIFont.systemFont(ofSize: 12)
        inspectionCountLabel.textColor = .systemBlue
        inspectionCountLabel.translatesAutoresizingMaskIntoConstraints = false
        
        dateLabel.font = UIFont.systemFont(ofSize: 12)
        dateLabel.textColor = .lightGray
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
            dateLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -40)
        ])
    }
    
    func configure(with customer: Customer) {
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

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        let dateString = dateFormatter.string(from: customer.createdDate ?? Date())
        dateLabel.text = "Added: \(dateString)"
    }
}

// MARK: - AddCustomerViewControllerDelegate Protocol
protocol AddCustomerViewControllerDelegate: AnyObject {
    func didAddCustomer(_ customer: Customer)
}
