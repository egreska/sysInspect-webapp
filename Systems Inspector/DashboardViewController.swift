//
//  DashboardViewController.swift
//  Systems Inspector
//
//  Created by Eric Greska on 5/22/25.
//

import UIKit
import CoreData
//import Charts

class DashboardViewController: UIViewController {
    
    // MARK: - Properties
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let recentInspectionsTableView = UITableView()
    private let recentCustomersTableView = UITableView()
    private var inspections: [Inspection] = []
    private var customers: [Customer] = []
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Dashboard"
        view.backgroundColor = .systemBackground
        
        setupScrollView()
        setupStatCards()
        setupRecentInspections()
        setupRecentCustomers()
        setupActionButtons()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        fetchData()
    }
    
    // MARK: - Setup UI
    private func setupScrollView() {
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
    }
    
    private func setupStatCards() {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = 10
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stackView.heightAnchor.constraint(equalToConstant: 100)
        ])
        
        // Add stat cards
        let customerCard = createStatCard(title: "Customers", value: "0", iconName: "person.3.fill")
        let inspectionCard = createStatCard(title: "Inspections", value: "0", iconName: "clipboard.fill")
        let issuesCard = createStatCard(title: "Issues", value: "0", iconName: "exclamationmark.triangle.fill")
        
        stackView.addArrangedSubview(customerCard)
        stackView.addArrangedSubview(inspectionCard)
        stackView.addArrangedSubview(issuesCard)
        
        // Tag the cards for updating later
        customerCard.tag = 1
        inspectionCard.tag = 2
        issuesCard.tag = 3
    }
    
    private func createStatCard(title: String, value: String, iconName: String) -> UIView {
        let card = UIView()
        card.backgroundColor = UIColor(white: 0.95, alpha: 1.0)
        card.layer.cornerRadius = 10
        
        // Icon
        let iconImageView = UIImageView(image: UIImage(systemName: iconName))
        iconImageView.tintColor = UIColor(red: 0.0, green: 0.4, blue: 0.8, alpha: 1.0)
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        
        // Title
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        titleLabel.textColor = .darkGray
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Value
        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        valueLabel.textColor = .black
        valueLabel.tag = 100 // Tag for updating later
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        
        card.addSubview(iconImageView)
        card.addSubview(titleLabel)
        card.addSubview(valueLabel)
        
        NSLayoutConstraint.activate([
            iconImageView.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            iconImageView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            iconImageView.widthAnchor.constraint(equalToConstant: 24),
            iconImageView.heightAnchor.constraint(equalToConstant: 24),
            
            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            
            valueLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            valueLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            valueLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16)
        ])
        
        return card
    }
    
    private func setupRecentInspections() {
        let sectionTitle = UILabel()
        sectionTitle.text = "Recent Inspections"
        sectionTitle.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        sectionTitle.translatesAutoresizingMaskIntoConstraints = false
        
        let viewAllButton = UIButton(type: .system)
        viewAllButton.setTitle("View All", for: .normal)
        viewAllButton.addTarget(self, action: #selector(viewAllInspections), for: .touchUpInside)
        viewAllButton.translatesAutoresizingMaskIntoConstraints = false
        
        recentInspectionsTableView.register(UITableViewCell.self, forCellReuseIdentifier: "InspectionCell")
        recentInspectionsTableView.dataSource = self
        recentInspectionsTableView.delegate = self
        recentInspectionsTableView.isScrollEnabled = false
        recentInspectionsTableView.translatesAutoresizingMaskIntoConstraints = false
        recentInspectionsTableView.tag = 1 // Tag to identify in delegate methods
        
        contentView.addSubview(sectionTitle)
        contentView.addSubview(viewAllButton)
        contentView.addSubview(recentInspectionsTableView)
        
        NSLayoutConstraint.activate([
            sectionTitle.topAnchor.constraint(equalTo: contentView.subviews[0].bottomAnchor, constant: 24),
            sectionTitle.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            
            viewAllButton.centerYAnchor.constraint(equalTo: sectionTitle.centerYAnchor),
            viewAllButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            recentInspectionsTableView.topAnchor.constraint(equalTo: sectionTitle.bottomAnchor, constant: 8),
            recentInspectionsTableView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            recentInspectionsTableView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            recentInspectionsTableView.heightAnchor.constraint(equalToConstant: 200)
        ])
    }
    
    private func setupRecentCustomers() {
        let sectionTitle = UILabel()
        sectionTitle.text = "Recent Customers"
        sectionTitle.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        sectionTitle.translatesAutoresizingMaskIntoConstraints = false
        
        let viewAllButton = UIButton(type: .system)
        viewAllButton.setTitle("View All", for: .normal)
        viewAllButton.addTarget(self, action: #selector(viewAllCustomers), for: .touchUpInside)
        viewAllButton.translatesAutoresizingMaskIntoConstraints = false
        
        recentCustomersTableView.register(UITableViewCell.self, forCellReuseIdentifier: "CustomerCell")
        recentCustomersTableView.dataSource = self
        recentCustomersTableView.delegate = self
        recentCustomersTableView.isScrollEnabled = false
        recentCustomersTableView.translatesAutoresizingMaskIntoConstraints = false
        recentCustomersTableView.tag = 2 // Tag to identify in delegate methods
        
        contentView.addSubview(sectionTitle)
        contentView.addSubview(viewAllButton)
        contentView.addSubview(recentCustomersTableView)
        
        NSLayoutConstraint.activate([
            sectionTitle.topAnchor.constraint(equalTo: recentInspectionsTableView.bottomAnchor, constant: 24),
            sectionTitle.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            
            viewAllButton.centerYAnchor.constraint(equalTo: sectionTitle.centerYAnchor),
            viewAllButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            recentCustomersTableView.topAnchor.constraint(equalTo: sectionTitle.bottomAnchor, constant: 8),
            recentCustomersTableView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            recentCustomersTableView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            recentCustomersTableView.heightAnchor.constraint(equalToConstant: 200)
        ])
    }
    
    private func setupActionButtons() {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        let newInspectionButton = createActionButton(title: "New Inspection", iconName: "plus.circle.fill", selector: #selector(createNewInspection))
        let generateReportButton = createActionButton(title: "Generate Report", iconName: "doc.text.fill", selector: #selector(generateReport))
        
        stackView.addArrangedSubview(newInspectionButton)
        stackView.addArrangedSubview(generateReportButton)
        
        contentView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: recentCustomersTableView.bottomAnchor, constant: 24),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stackView.heightAnchor.constraint(equalToConstant: 60),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24)
        ])
    }
    
    private func createActionButton(title: String, iconName: String, selector: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.backgroundColor = UIColor(red: 0.0, green: 0.4, blue: 0.8, alpha: 1.0)
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        button.setImage(UIImage(systemName: iconName), for: .normal)
        button.tintColor = .white
        button.layer.cornerRadius = 10
        
        // Position image to the left of text
        button.semanticContentAttribute = .forceLeftToRight
        button.imageEdgeInsets = UIEdgeInsets(top: 0, left: -8, bottom: 0, right: 0)
        button.titleEdgeInsets = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 0)
        
        button.addTarget(self, action: selector, for: .touchUpInside)
        
        return button
    }
    
    // MARK: - Data
    private func fetchData() {
        fetchRecentInspections()
        fetchRecentCustomers()
        updateStatCards()
    }
    
    private func fetchRecentInspections() {
        let fetchRequest: NSFetchRequest<Inspection> = Inspection.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        fetchRequest.fetchLimit = 5
        
        do {
            inspections = try CoreDataManager.shared.context.fetch(fetchRequest)
            recentInspectionsTableView.reloadData()
        } catch {
            print("Error fetching recent inspections: \(error)")
        }
    }
    
    private func fetchRecentCustomers() {
        let fetchRequest: NSFetchRequest<Customer> = Customer.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdDate", ascending: false)]
        fetchRequest.fetchLimit = 5
        
        do {
            customers = try CoreDataManager.shared.context.fetch(fetchRequest)
            recentCustomersTableView.reloadData()
        } catch {
            print("Error fetching recent customers: \(error)")
        }
    }
    
    private func updateStatCards() {
        // Update customer count
        let customerRequest: NSFetchRequest<Customer> = Customer.fetchRequest()
        
        // Update inspection count
        let inspectionRequest: NSFetchRequest<Inspection> = Inspection.fetchRequest()
        
        // Update issues count (count inspections with damage)
        let issuesRequest: NSFetchRequest<InspectionItem> = InspectionItem.fetchRequest()
        issuesRequest.predicate = NSPredicate(
            format: "upright == YES OR beam == YES OR wireDeck == YES OR basePlate == YES OR anchors == YES OR bracingDamage == YES OR postProtector == YES OR aisleGuarding == YES"
        )
        
        do {
            let customerCount = try CoreDataManager.shared.context.count(for: customerRequest)
            let inspectionCount = try CoreDataManager.shared.context.count(for: inspectionRequest)
            let issuesCount = try CoreDataManager.shared.context.count(for: issuesRequest)
            
            // Update the value labels
            if let customerCard = view.viewWithTag(1),
               let customerValueLabel = customerCard.viewWithTag(100) as? UILabel {
                customerValueLabel.text = "\(customerCount)"
            }
            
            if let inspectionCard = view.viewWithTag(2),
               let inspectionValueLabel = inspectionCard.viewWithTag(100) as? UILabel {
                inspectionValueLabel.text = "\(inspectionCount)"
            }
            
            if let issuesCard = view.viewWithTag(3),
               let issuesValueLabel = issuesCard.viewWithTag(100) as? UILabel {
                issuesValueLabel.text = "\(issuesCount)"
            }
        } catch {
            print("Error updating stat cards: \(error)")
        }
    }
    
    // MARK: - Actions
    @objc private func viewAllInspections() {
        // Navigate to the Reports tab
        if let tabBarController = tabBarController {
            tabBarController.selectedIndex = 1
        }
    }
    
    @objc private func viewAllCustomers() {
        // Navigate to the Customers tab
        if let tabBarController = tabBarController {
            tabBarController.selectedIndex = 0
        }
    }
    
    @objc private func createNewInspection() {
        // Show customer selection or create new customer
        let alertController = UIAlertController(
            title: "New Inspection",
            message: "Select an option to continue",
            preferredStyle: .actionSheet
        )

        alertController.addAction(UIAlertAction(title: "Select Existing Customer", style: .default) { [weak self] _ in
            self?.showCustomerSelectionForCustomerDetails() // Renamed for clarity
        })

        alertController.addAction(UIAlertAction(title: "Create New Customer", style: .default) { [weak self] _ in
            let addCustomerVC = AddCustomerViewController()
            addCustomerVC.delegate = self // This delegate will handle navigation after creation
            let navController = UINavigationController(rootViewController: addCustomerVC)
            self?.present(navController, animated: true)
        })

        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let popoverController = alertController.popoverPresentationController {
            popoverController.sourceView = view
            popoverController.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popoverController.permittedArrowDirections = []
        }

        present(alertController, animated: true)
    }
    
    private func showCustomerSelectionForCustomerDetails() {
        let customerSelectionVC = CustomerSelectionViewController()
        customerSelectionVC.title = "Select Customer"
        customerSelectionVC.delegate = self // DashboardVC will handle the selection

        let navController = UINavigationController(rootViewController: customerSelectionVC)
        customerSelectionVC.navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(dismissModalController)
        )

        present(navController, animated: true)
    }
    
    @objc private func dismissModalController(_ sender: UIBarButtonItem) {
        dismiss(animated: true)
    }
    
    @objc private func generateReport() {
        // Navigate to the Reports tab
        if let tabBarController = tabBarController {
            tabBarController.selectedIndex = 1
        }
    }
}

// MARK: - UITableViewDataSource
extension DashboardViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch tableView.tag {
        case 1: // Recent Inspections
            return inspections.count
        case 2: // Recent Customers
            return customers.count
        default:
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch tableView.tag {
        case 1: // Recent Inspections
            let cell = tableView.dequeueReusableCell(withIdentifier: "InspectionCell", for: indexPath)
            let inspection = inspections[indexPath.row]

            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium

            // Safely unwrap inspection.date
            let dateString = inspection.date.map { dateFormatter.string(from: $0) } ?? "Unknown Date"
            cell.textLabel?.text = "Inspection on \(dateString)"

            // Safely unwrap inspection.customer and then access its name
            let customerName = inspection.customer?.name ?? "Unknown Customer"
            cell.detailTextLabel?.text = "Customer: \(customerName)"
            cell.accessoryType = .disclosureIndicator

            return cell
            
        case 2: // Recent Customers
            let cell = tableView.dequeueReusableCell(withIdentifier: "CustomerCell", for: indexPath)
            let customer = customers[indexPath.row]
            
            cell.textLabel?.text = customer.name // This is now company name
            
            // Show site and contact name if available
            var detailText = ""
            if let site = customer.site, !site.isEmpty {
                detailText += "Site: \(site)"
            }
            if let contactName = customer.contactName, !contactName.isEmpty {
                if !detailText.isEmpty { detailText += " • " }
                detailText += "Contact: \(contactName)"
            }
            if detailText.isEmpty {
                detailText = customer.address ?? "No additional info"
            }
            
            cell.detailTextLabel?.text = detailText
            cell.accessoryType = .disclosureIndicator
            
            return cell
            
        default:
            return UITableViewCell()
        }
    }
}

// MARK: - UITableViewDelegate
extension DashboardViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        switch tableView.tag {
        case 1: // Recent Inspections
            let inspection = inspections[indexPath.row]
            guard let customer = inspection.customer else {
                // Handle the case where customer is nil (e.g., log, show alert, or just return)
                print("Error: Inspection has no associated customer.")
                return
            }

            // Navigate to the inspection details
            let customerDetailsVC = CustomerDetailsViewController(customer: customer)
            navigationController?.pushViewController(customerDetailsVC, animated: true)
            
        case 2: // Recent Customers
            let customer = customers[indexPath.row]
            
            // Navigate to the customer details
            let customerDetailsVC = CustomerDetailsViewController(customer: customer)
            navigationController?.pushViewController(customerDetailsVC, animated: true)
            
        default:
            break
        }
    }
}

// MARK: - AddCustomerViewControllerDelegate
extension DashboardViewController: AddCustomerViewControllerDelegate {
    func didAddCustomer(_ customer: Customer) {
        // Update the data (optional, but good practice)
        fetchData()

        // Navigate to the newly created customer's details screen
        if let tabBarController = tabBarController as? MainTabBarController {
            // Dismiss the AddCustomerVC modal first if it was presented modally
            // (AddCustomerViewController already handles its own dismissal in saveCustomer())
            tabBarController.navigateToCustomerDetails(customer)
        }
    }
}

// MARK: - CustomerSelectionDelegate
extension DashboardViewController: CustomerSelectionDelegate {
    func didSelectCustomer(_ customer: Customer) {
        // Dismiss the CustomerSelectionVC modal
        dismiss(animated: true) { [weak self] in
            // Navigate to the selected customer's details screen
            if let tabBarController = self?.tabBarController as? MainTabBarController {
                tabBarController.navigateToCustomerDetails(customer)
            }
        }
    }
}
