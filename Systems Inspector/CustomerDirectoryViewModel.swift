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
    
    // MARK: - Pagination Properties
    private let pageSize = 20
    private var currentPage = 0
    private var isLoadingMore = false
    @Published var hasMoreCustomers = true
    private var totalCustomerCount = 0
    
    // MARK: - Public Methods
    
    /// Fetch initial page of customers
    func fetchCustomers() {
        currentPage = 0
        customers = []
        originalCustomers = []
        hasMoreCustomers = true
        fetchNextPage()
    }
    
    /// Fetch next page of customers (for pagination)
    func fetchNextPage() {
        guard !isLoadingMore, hasMoreCustomers else {
            print("CustomerDirectoryViewModel: Already loading or no more customers")
            return
        }
        
        guard let currentUserID = coreDataManager.currentUserID else {
            print("CustomerDirectoryViewModel: No current user ID. Not fetching customers.")
            customers = []
            originalCustomers = []
            hasMoreCustomers = false
            return
        }
        
        isLoadingMore = true
        
        // Start performance timing
        PerformanceOptimizer.shared.startTiming("fetchCustomers")
        
        // Use optimized fetch request
        let fetchRequest = PerformanceOptimizer.shared.optimizedCustomerFetchRequest(
            pageSize: pageSize,
            offset: currentPage * pageSize,
            userId: currentUserID
        )
        
        do {
            // Get total count (only on first page)
            if currentPage == 0 {
                let countRequest = NSFetchRequest<Customer>(entityName: "Customer")
                countRequest.predicate = NSPredicate(format: "userId == %@", currentUserID as CVarArg)
                totalCustomerCount = try coreDataManager.context.count(for: countRequest)
                print("📊 Total customers: \(totalCustomerCount)")
            }
            
            let newCustomers = try coreDataManager.context.fetch(fetchRequest)
            print("📄 Fetched page \(currentPage + 1): \(newCustomers.count) customers")
            
            if currentPage == 0 {
                customers = newCustomers
                originalCustomers = newCustomers
            } else {
                customers.append(contentsOf: newCustomers)
                originalCustomers.append(contentsOf: newCustomers)
            }
            
            currentPage += 1
            
            // Check if there are more pages
            hasMoreCustomers = customers.count < totalCustomerCount
            isLoadingMore = false
            
            // End performance timing
            PerformanceOptimizer.shared.endTiming("fetchCustomers")
            
            print("📊 Loaded \(customers.count)/\(totalCustomerCount) customers")
            
            // Clean up expired cache periodically
            if currentPage % 5 == 0 {
                PerformanceOptimizer.shared.clearExpiredCache()
            }
            
        } catch {
            print("Error fetching customers: \(error)")
            isLoadingMore = false
            hasMoreCustomers = false
            PerformanceOptimizer.shared.endTiming("fetchCustomers")
        }
    }
    
    /// Check if should load more data (called when scrolling)
    func shouldLoadMore(currentIndex: Int) -> Bool {
        // Load more when user is within 5 items of the end
        let threshold = customers.count - 5
        return currentIndex >= threshold && hasMoreCustomers && !isLoadingMore
    }
    
    func filterCustomers(searchText: String) {
        guard let currentUserID = coreDataManager.currentUserID else {
            print("CustomerDirectoryViewModel: No current user ID. Cannot filter customers.")
            customers = []
            return
        }

        if searchText.isEmpty {
            // Reset to paginated view
            fetchCustomers()
            return
        }
        
        // Disable pagination during search
        hasMoreCustomers = false
        
        let fetchRequest = NSFetchRequest<Customer>(entityName: "Customer")
        
        // Create a predicate to filter by name, site, contact name, phone, address, city, state, or zip code
        let searchPredicate = NSPredicate(
            format: "name CONTAINS[cd] %@ OR site CONTAINS[cd] %@ OR contactName CONTAINS[cd] %@ OR phone CONTAINS[cd] %@ OR address CONTAINS[cd] %@ OR city CONTAINS[cd] %@ OR state CONTAINS[cd] %@ OR zipCode CONTAINS[cd] %@",
            searchText, searchText, searchText, searchText, searchText, searchText, searchText, searchText
        )
        
        // Combine with user ID predicate
        let userPredicate = NSPredicate(format: "userId == %@", currentUserID as CVarArg)
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [searchPredicate, userPredicate])

        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        // No pagination during search - load all matching results
        fetchRequest.fetchBatchSize = 50
        
        do {
            customers = try coreDataManager.context.fetch(fetchRequest)
            print("🔍 Search returned \(customers.count) results")
        } catch {
            print("Error filtering customers: \(error)")
        }
    }
    
    func deleteCustomer(at index: Int) {
        guard index < customers.count else { return }
        
        let customerToDelete = customers[index]
        
        // Use CoreDataManager.deleteObject for CloudKit sync
        coreDataManager.deleteObject(customerToDelete)
        
        // The customer will be removed from `customers` array when fetchCustomers() is called again
        // or implicitly if you have a sophisticated NSFetchedResultsController setup.
        // For simplicity with @Published, we'll refetch.
        fetchCustomers() // Refresh the list after deletion
    }
    
    
    
    // MARK: - Customer Stats
    func getTotalInspectionCount() -> Int {
        var total = 0
        // Ensure we only count inspections for customers owned by the current user
        for customer in customers { // 'customers' array already filtered by user ID
            total += customer.inspections?.count ?? 0
        }
        return total
    }
    
    func getRecentCustomers(limit: Int = 5) -> [Customer] {
        guard let currentUserID = coreDataManager.currentUserID else { return [] }

        let fetchRequest = NSFetchRequest<Customer>(entityName: "Customer")
        fetchRequest.predicate = NSPredicate(format: "userId == %@", currentUserID as CVarArg)
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
        guard let currentUserID = coreDataManager.currentUserID else { return [] }

        // First fetch all customers for the current user
        let fetchRequest = NSFetchRequest<Customer>(entityName: "Customer")
        fetchRequest.predicate = NSPredicate(format: "userId == %@", currentUserID as CVarArg)
        
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
        guard let currentUserID = coreDataManager.currentUserID else { return [] }

        let fetchRequest = NSFetchRequest<Customer>(entityName: "Customer")
        let searchPredicate = NSPredicate(format: "name CONTAINS[cd] %@", name)
        let userPredicate = NSPredicate(format: "userId == %@", currentUserID as CVarArg)
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [searchPredicate, userPredicate])
        
        do {
            return try coreDataManager.context.fetch(fetchRequest)
        } catch {
            print("Error searching customers by name: \(error)")
            return []
        }
    }
    
    func searchCustomersByAddress(_ address: String) -> [Customer] {
        guard let currentUserID = coreDataManager.currentUserID else { return [] }

        let fetchRequest = NSFetchRequest<Customer>(entityName: "Customer")
        let searchPredicate = NSPredicate(format: "address CONTAINS[cd] %@", address)
        let userPredicate = NSPredicate(format: "userId == %@", currentUserID as CVarArg)
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [searchPredicate, userPredicate])
        
        do {
            return try coreDataManager.context.fetch(fetchRequest)
        } catch {
            print("Error searching customers by address: \(error)")
            return []
        }
    }
    
    func getCustomersWithInspectionsBetween(startDate: Date, endDate: Date) -> [Customer] {
        guard let currentUserID = coreDataManager.currentUserID else { return [] }

        let fetchRequest = NSFetchRequest<Customer>(entityName: "Customer")
        let datePredicate = NSPredicate(
            format: "ANY inspections.date >= %@ AND ANY inspections.date <= %@",
            startDate as NSDate, endDate as NSDate
        )
        let userPredicate = NSPredicate(format: "userId == %@", currentUserID as CVarArg)
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [datePredicate, userPredicate])
        
        do {
            return try coreDataManager.context.fetch(fetchRequest)
        } catch {
            print("Error fetching customers with inspections in date range: \(error)")
            return []
        }
    }
}
