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
    @Published var isLoading = false
    @Published var errorMessage: String?
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
        errorMessage = nil
        currentPage = 0
        customers = []
        originalCustomers = []
        hasMoreCustomers = true
        isLoading = true
        fetchNextPage()
    }
    
    /// Clear any displayed error (e.g. when user dismisses alert).
    func clearError() {
        errorMessage = nil
    }
    
    /// Fetch next page of customers (for pagination)
    func fetchNextPage() {
        guard !isLoadingMore, hasMoreCustomers else { return }
        guard let currentUserID = UserManager.shared.sessionUserId else {
            customers = []
            originalCustomers = []
            hasMoreCustomers = false
            isLoading = false
            return
        }
        let isFirstPage = (currentPage == 0)
        isLoadingMore = true
        if isFirstPage { isLoading = true }
        let page = currentPage
        let fetchRequest = PerformanceOptimizer.shared.optimizedCustomerFetchRequest(
            pageSize: pageSize,
            offset: page * pageSize,
            userId: currentUserID
        )
        PerformanceOptimizer.shared.startTiming("fetchCustomers")
        coreDataManager.performBackgroundTask { [weak self] context in
            guard let self = self else { return }
            do {
                let countRequest = NSFetchRequest<Customer>(entityName: "Customer")
                countRequest.predicate = NSPredicate(format: "userId == %@", currentUserID as CVarArg)
                let total = try context.count(for: countRequest)
                let result = try context.fetch(fetchRequest)
                let objectIDs = result.map(\.objectID)
                DispatchQueue.main.async {
                    let mainContext = self.coreDataManager.context
                    let newCustomers = objectIDs.compactMap { try? mainContext.existingObject(with: $0) as? Customer }
                    if page == 0 {
                        self.customers = newCustomers
                        self.originalCustomers = newCustomers
                        self.currentPage = 1
                    } else {
                        self.customers.append(contentsOf: newCustomers)
                        self.originalCustomers.append(contentsOf: newCustomers)
                        self.currentPage += 1
                    }
                    self.totalCustomerCount = total
                    self.hasMoreCustomers = self.customers.count < total
                    self.isLoadingMore = false
                    self.isLoading = false
                    PerformanceOptimizer.shared.endTiming("fetchCustomers")
                }
            } catch {
                DispatchQueue.main.async {
                    self.isLoadingMore = false
                    self.isLoading = false
                    self.hasMoreCustomers = false
                    PerformanceOptimizer.shared.endTiming("fetchCustomers")
                    self.errorMessage = "Could not load customers. Pull down to try again."
                }
            }
        }
    }
    
    /// Check if should load more data (called when scrolling)
    func shouldLoadMore(currentIndex: Int) -> Bool {
        // Load more when user is within 5 items of the end
        let threshold = customers.count - 5
        return currentIndex >= threshold && hasMoreCustomers && !isLoadingMore
    }
    
    func filterCustomers(searchText: String) {
        guard let currentUserID = UserManager.shared.sessionUserId else {
            #if DEBUG
            print("CustomerDirectoryViewModel: No current user ID. Cannot filter customers.")
            #endif
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
        fetchRequest.fetchBatchSize = 50
        fetchRequest.fetchLimit = 500  // Limit search results for performance
        
        do {
            errorMessage = nil
            customers = try coreDataManager.context.fetch(fetchRequest)
            #if DEBUG
            print("🔍 Search returned \(customers.count) results")
            #endif
        } catch {
            #if DEBUG
            print("Error filtering customers: \(error)")
            #endif
            errorMessage = "Search failed. Please try again."
        }
    }
    
    /// Deletes the customer at the given index. Calls completion with false if delete/save failed.
    /// Removes customer from the displayed list without deleting from Core Data. Caller can show "Undo" and then either restoreCustomer or confirmDeleteCustomer.
    func removeCustomerFromList(at index: Int) -> Customer? {
        guard index < customers.count else { return nil }
        let customer = customers.remove(at: index)
        if let idx = originalCustomers.firstIndex(where: { $0.objectID == customer.objectID }) {
            originalCustomers.remove(at: idx)
        }
        return customer
    }
    
    /// Re-inserts a customer that was removed via removeCustomerFromList (undo).
    func restoreCustomer(_ customer: Customer) {
        if !customers.contains(where: { $0.objectID == customer.objectID }) {
            customers.append(customer)
            originalCustomers.append(customer)
            customers.sort { ($0.name ?? "") < ($1.name ?? "") }
            originalCustomers.sort { ($0.name ?? "") < ($1.name ?? "") }
        }
    }
    
    /// Permanently deletes the customer from Core Data.
    func confirmDeleteCustomer(_ customer: Customer, completion: ((Bool) -> Void)? = nil) {
        let success = coreDataManager.deleteObject(customer)
        if success {
            errorMessage = nil
            if let idx = customers.firstIndex(where: { $0.objectID == customer.objectID }) {
                customers.remove(at: idx)
            }
            if let idx = originalCustomers.firstIndex(where: { $0.objectID == customer.objectID }) {
                originalCustomers.remove(at: idx)
            }
        }
        completion?(success)
    }
}
