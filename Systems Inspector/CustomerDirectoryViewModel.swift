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
    private var currentPage = 0
    private var isLoadingMore = false
    @Published var hasMoreCustomers = true
    private var totalCustomerCount = 0
    private var listGeneration = 0
    private var inspectionCounts: [NSManagedObjectID: Int] = [:]
    
    // MARK: - Public Methods
    
    /// Fetch initial page of customers
    func fetchCustomers() {
        errorMessage = nil
        listGeneration += 1
        currentPage = 0
        hasMoreCustomers = true
        isLoadingMore = false
        isLoading = true
        inspectionCounts = [:]
        customers = []
        originalCustomers = []
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
        let generation = listGeneration
        let viewContext = coreDataManager.context
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let fetched = try await sessionCustomerPage(page, userId: currentUserID, in: viewContext)
                guard generation == self.listGeneration else { return }
                self.recordInspectionCounts(for: fetched.customers, replacing: page == 0)
                if page == 0 {
                    self.customers = fetched.customers
                    self.originalCustomers = fetched.customers
                    self.currentPage = 1
                } else {
                    self.customers.append(contentsOf: fetched.customers)
                    self.originalCustomers.append(contentsOf: fetched.customers)
                    self.currentPage += 1
                }
                self.totalCustomerCount = fetched.total
                self.hasMoreCustomers = self.customers.count < fetched.total
                self.isLoadingMore = false
                self.isLoading = false
            } catch {
                guard generation == self.listGeneration else { return }
                self.isLoadingMore = false
                self.isLoading = false
                self.hasMoreCustomers = false
                self.errorMessage = "Could not load customers. Pull down to try again."
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
            fetchCustomers()
            return
        }

        listGeneration += 1
        isLoadingMore = false
        hasMoreCustomers = false
        
        do {
            errorMessage = nil
            let fetched = try fetchSessionCustomers(.search(searchText), userId: currentUserID, in: coreDataManager.context)
            recordInspectionCounts(for: fetched.customers, replacing: true)
            customers = fetched.customers
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
    
    func inspectionCount(for customer: Customer) -> Int {
        inspectionCounts[customer.objectID] ?? 0
    }

    /// Re-inserts a customer that was removed via removeCustomerFromList (undo).
    func restoreCustomer(_ customer: Customer) {
        if !customers.contains(where: { $0.objectID == customer.objectID }) {
            customers.append(customer)
            originalCustomers.append(customer)
            customers.sort { ($0.name ?? "") < ($1.name ?? "") }
            originalCustomers.sort { ($0.name ?? "") < ($1.name ?? "") }
            recordInspectionCounts(for: [customer], replacing: false)
        }
    }

    private func recordInspectionCounts(for customers: [Customer], replacing: Bool) {
        guard let userId = UserManager.shared.sessionUserId else { return }
        let counts = sessionInspectionCounts(for: customers, userId: userId, in: coreDataManager.context)
        if replacing {
            inspectionCounts = counts
        } else {
            for (id, count) in counts {
                inspectionCounts[id] = count
            }
        }
    }
    
    /// Permanently deletes the customer from Core Data.
    func confirmDeleteCustomer(_ customer: Customer, completion: ((Bool) -> Void)? = nil) {
        let success = coreDataManager.deleteObject(customer)
        if success {
            errorMessage = nil
            CustomerSearchIndex.refreshFromStore()
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
