//
//  CustomerDirectoryViewModel.swift
//  Systems Inspector
//
//  Created by Eric Greska on 5/22/25.

import Combine
import CoreData

class CustomerDirectoryViewModel {
    // MARK: - Properties
    @Published var customers: [Customer] = []
    private let coreDataManager = CoreDataManager.shared
    private var originalCustomers: [Customer] = []
    
    // MARK: - Public Methods
    func fetchCustomers() {
        let fetchRequest = NSFetchRequest<Customer>(entityName: "Customer")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        do {
            customers = try coreDataManager.context.fetch(fetchRequest)
            originalCustomers = customers
        } catch {
            print("Error fetching customers: \(error)")
        }
    }
    
    func filterCustomers(searchText: String) {
        if searchText.isEmpty {
            customers = originalCustomers
            return
        }
        
        let fetchRequest = NSFetchRequest<Customer>(entityName: "Customer")
        
        // Create a predicate to filter by name, site, contact name, phone, address, city, state, or zip code
        fetchRequest.predicate = NSPredicate(
            format: "name CONTAINS[cd] %@ OR site CONTAINS[cd] %@ OR contactName CONTAINS[cd] %@ OR phone CONTAINS[cd] %@ OR address CONTAINS[cd] %@ OR city CONTAINS[cd] %@ OR state CONTAINS[cd] %@ OR zipCode CONTAINS[cd] %@",
            searchText, searchText, searchText, searchText, searchText, searchText, searchText, searchText
        )
        
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        do {
            customers = try coreDataManager.context.fetch(fetchRequest)
        } catch {
            print("Error filtering customers: \(error)")
        }
    }
    
    func deleteCustomer(at index: Int) {
        guard index < customers.count else { return }
        
        let customer = customers[index]
        
        // We need to handle the deletion of all related inspections as well
        // This can be handled by setting appropriate delete rules in Core Data model
        // or by manually deleting related items here
        
        coreDataManager.context.delete(customer)
        coreDataManager.saveContext()
        
        // Remove from the array
        customers.remove(at: index)
    }
    
    func deleteAllCustomers() {
        // This is a dangerous operation and should be used only in development/testing
        #if DEBUG
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = Customer.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        
        do {
            try coreDataManager.context.execute(deleteRequest)
            coreDataManager.saveContext()
            customers = []
            originalCustomers = []
        } catch {
            print("Error deleting all customers: \(error)")
        }
        #endif
    }
    
    // MARK: - Customer Stats
    func getTotalInspectionCount() -> Int {
        var total = 0
        for customer in customers {
            total += customer.inspections?.count ?? 0
        }
        return total
    }
    
    func getRecentCustomers(limit: Int = 5) -> [Customer] {
        let fetchRequest = NSFetchRequest<Customer>(entityName: "Customer")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdDate", ascending: false)]
        fetchRequest.fetchLimit = limit
        
        do {
            return try coreDataManager.context.fetch(fetchRequest)
        } catch {
            print("Error fetching recent customers: \(error)")
            return []
        }
    }
    
    func getCustomersWithMostInspections(limit: Int = 5) -> [Customer] {
        // First fetch all customers
        let fetchRequest = NSFetchRequest<Customer>(entityName: "Customer")
        
        do {
            let allCustomers = try coreDataManager.context.fetch(fetchRequest)
            
            // Sort by inspection count (descending)
            let sortedCustomers = allCustomers.sorted {
                ($0.inspections?.count ?? 0) > ($1.inspections?.count ?? 0)
            }
            
            // Return the top N customers
            return Array(sortedCustomers.prefix(limit))
        } catch {
            print("Error fetching customers with most inspections: \(error)")
            return []
        }
    }
    
    // MARK: - Search and Filter Methods
    func searchCustomersByName(_ name: String) -> [Customer] {
        let fetchRequest = NSFetchRequest<Customer>(entityName: "Customer")
        fetchRequest.predicate = NSPredicate(format: "name CONTAINS[cd] %@", name)
        
        do {
            return try coreDataManager.context.fetch(fetchRequest)
        } catch {
            print("Error searching customers by name: \(error)")
            return []
        }
    }
    
    func searchCustomersByAddress(_ address: String) -> [Customer] {
        let fetchRequest = NSFetchRequest<Customer>(entityName: "Customer")
        fetchRequest.predicate = NSPredicate(format: "address CONTAINS[cd] %@", address)
        
        do {
            return try coreDataManager.context.fetch(fetchRequest)
        } catch {
            print("Error searching customers by address: \(error)")
            return []
        }
    }
    
    func getCustomersWithInspectionsBetween(startDate: Date, endDate: Date) -> [Customer] {
        let fetchRequest = NSFetchRequest<Customer>(entityName: "Customer")
        fetchRequest.predicate = NSPredicate(
            format: "ANY inspections.date >= %@ AND ANY inspections.date <= %@",
            startDate as NSDate, endDate as NSDate
        )
        
        do {
            return try coreDataManager.context.fetch(fetchRequest)
        } catch {
            print("Error fetching customers with inspections in date range: \(error)")
            return []
        }
    }
}
