// CustomerSelectionViewController.swift
import UIKit
import CoreData

protocol CustomerSelectionDelegate: AnyObject {
    func didSelectCustomer(_ customer: Customer)
}

class CustomerSelectionViewController: UITableViewController {
    var allCustomers: [Customer] = []
    weak var delegate: CustomerSelectionDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "CustomerCell")
        fetchCustomers() // Fetch customers when view loads
    }

    private func fetchCustomers() {
        let fetchRequest: NSFetchRequest<Customer> = Customer.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]

        do {
            allCustomers = try CoreDataManager.shared.context.fetch(fetchRequest)
            tableView.reloadData()
        } catch {
            print("Error fetching customers for selection: \(error)")
        }
    }

    // MARK: - UITableViewDataSource
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return allCustomers.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CustomerCell", for: indexPath)
        let customer = allCustomers[indexPath.row]
        cell.textLabel?.text = customer.name
        cell.detailTextLabel?.text = customer.address
        return cell
    }

    // MARK: - UITableViewDelegate
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let selectedCustomer = allCustomers[indexPath.row]
        delegate?.didSelectCustomer(selectedCustomer)
        dismiss(animated: true)
    }
}
