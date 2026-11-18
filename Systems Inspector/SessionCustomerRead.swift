//
//  SessionCustomerRead.swift
//  Systems Inspector
//

import CoreData

enum SessionCustomerQuery {
    case page(offset: Int)
    case search(String)
}

let sessionCustomerPageSize = 20

private func sessionUserPredicate(userId: UUID) -> NSPredicate {
    NSPredicate(format: "userId == %@", userId as CVarArg)
}

private func sessionInspectionsPredicate(customer: Customer, userId: UUID) -> NSPredicate {
    NSCompoundPredicate(andPredicateWithSubpredicates: [
        NSPredicate(format: "customer == %@", customer),
        sessionUserPredicate(userId: userId)
    ])
}

private func sessionInspectionItemsPredicate(inspection: Inspection, userId: UUID) -> NSPredicate {
    NSCompoundPredicate(andPredicateWithSubpredicates: [
        NSPredicate(format: "inspection == %@", inspection),
        sessionUserPredicate(userId: userId)
    ])
}

func fetchSessionCustomers(
    _ query: SessionCustomerQuery,
    userId: UUID,
    in context: NSManagedObjectContext
) throws -> (customers: [Customer], total: Int?) {
    let fetchRequest = NSFetchRequest<Customer>(entityName: "Customer")
    fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
    let userPredicate = sessionUserPredicate(userId: userId)
    switch query {
    case .page(let offset):
        fetchRequest.predicate = userPredicate
        fetchRequest.fetchLimit = sessionCustomerPageSize
        fetchRequest.fetchOffset = offset
        fetchRequest.fetchBatchSize = sessionCustomerPageSize
        fetchRequest.propertiesToFetch = [
            "id", "name", "site", "contactName",
            "phone", "address", "city", "state",
            "zipCode", "userId", "createdDate"
        ]
        fetchRequest.returnsObjectsAsFaults = true
        let countRequest = NSFetchRequest<Customer>(entityName: "Customer")
        countRequest.predicate = userPredicate
        let total = try context.count(for: countRequest)
        return (customers: try context.fetch(fetchRequest), total: total)
    case .search(let searchText):
        let searchPredicate = NSPredicate(
            format: "name CONTAINS[cd] %@ OR site CONTAINS[cd] %@ OR contactName CONTAINS[cd] %@ OR phone CONTAINS[cd] %@ OR address CONTAINS[cd] %@ OR city CONTAINS[cd] %@ OR state CONTAINS[cd] %@ OR zipCode CONTAINS[cd] %@",
            searchText, searchText, searchText, searchText, searchText, searchText, searchText, searchText
        )
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [searchPredicate, userPredicate])
        fetchRequest.fetchBatchSize = 50
        fetchRequest.fetchLimit = 500
        return (customers: try context.fetch(fetchRequest), total: nil)
    }
}

func fetchSessionInspections(
    for customer: Customer,
    userId: UUID,
    in context: NSManagedObjectContext
) throws -> [Inspection] {
    let request = NSFetchRequest<Inspection>(entityName: "Inspection")
    request.predicate = sessionInspectionsPredicate(customer: customer, userId: userId)
    request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
    return try context.fetch(request)
}

func fetchSessionInspectionItems(
    for inspection: Inspection,
    userId: UUID,
    in context: NSManagedObjectContext
) throws -> [InspectionItem] {
    let request = NSFetchRequest<InspectionItem>(entityName: "InspectionItem")
    request.predicate = sessionInspectionItemsPredicate(inspection: inspection, userId: userId)
    return try context.fetch(request)
}

struct SessionCustomerSearchEntry: Equatable {
    let id: UUID
    let name: String
    let site: String
}

func fetchSessionCustomerSearchEntries(
    userId: UUID,
    in context: NSManagedObjectContext
) throws -> [SessionCustomerSearchEntry] {
    let request = NSFetchRequest<Customer>(entityName: "Customer")
    request.predicate = sessionUserPredicate(userId: userId)
    request.propertiesToFetch = ["id", "name", "site"]
    request.returnsObjectsAsFaults = false
    return try context.fetch(request).compactMap { customer in
        guard let id = customer.id else { return nil }
        return SessionCustomerSearchEntry(id: id, name: customer.name ?? "", site: customer.site ?? "")
    }
}

func fetchSessionCustomer(
    id: UUID,
    userId: UUID,
    in context: NSManagedObjectContext
) throws -> Customer? {
    let request = NSFetchRequest<Customer>(entityName: "Customer")
    request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
        NSPredicate(format: "id == %@", id as CVarArg),
        sessionUserPredicate(userId: userId)
    ])
    request.fetchLimit = 1
    return try context.fetch(request).first
}

func sessionInspectionCount(
    for customer: Customer,
    userId: UUID,
    in context: NSManagedObjectContext
) throws -> Int {
    let request = NSFetchRequest<Inspection>(entityName: "Inspection")
    request.predicate = sessionInspectionsPredicate(customer: customer, userId: userId)
    return try context.count(for: request)
}

func sessionInspectionItemCount(
    for inspection: Inspection,
    userId: UUID,
    in context: NSManagedObjectContext
) throws -> Int {
    let request = NSFetchRequest<InspectionItem>(entityName: "InspectionItem")
    request.predicate = sessionInspectionItemsPredicate(inspection: inspection, userId: userId)
    return try context.count(for: request)
}

func sessionInspectionCounts(
    for customers: [Customer],
    userId: UUID,
    in context: NSManagedObjectContext
) -> [NSManagedObjectID: Int] {
    var counts: [NSManagedObjectID: Int] = [:]
    counts.reserveCapacity(customers.count)
    for customer in customers {
        counts[customer.objectID] = (try? sessionInspectionCount(for: customer, userId: userId, in: context)) ?? 0
    }
    return counts
}

func sessionInspectionItemCounts(
    for inspections: [Inspection],
    userId: UUID,
    in context: NSManagedObjectContext
) -> [NSManagedObjectID: Int] {
    var counts: [NSManagedObjectID: Int] = [:]
    counts.reserveCapacity(inspections.count)
    for inspection in inspections {
        counts[inspection.objectID] = (try? sessionInspectionItemCount(for: inspection, userId: userId, in: context)) ?? 0
    }
    return counts
}

enum SessionReadHopError: Error, Equatable {
    case storeUnavailable
    case unresolved
}

/// Customers for one page, on the view context the caller passed.
@MainActor
func sessionCustomerPage(
    _ page: Int,
    userId: UUID,
    in viewContext: NSManagedObjectContext
) async throws -> (customers: [Customer], total: Int) {
    let fetched = try await readInBackground(of: viewContext) { context in
        let fetchedPage = try fetchSessionCustomers(
            .page(offset: page * sessionCustomerPageSize),
            userId: userId,
            in: context
        )
        return HoppedPage(
            ids: fetchedPage.customers.map(\.objectID),
            total: fetchedPage.total ?? 0
        )
    }
    let customers: [Customer] = try materialize(fetched.ids, in: viewContext)
    return (customers, fetched.total)
}

/// Inspections for one Customer, newest first, on the view context the caller passed.
@MainActor
func sessionInspections(
    for customer: Customer,
    userId: UUID,
    in viewContext: NSManagedObjectContext
) async throws -> [Inspection] {
    let customerID = customer.objectID
    let ids = try await readInBackground(of: viewContext) { context in
        guard let backgroundCustomer = try? context.existingObject(with: customerID) as? Customer else {
            throw SessionReadHopError.unresolved
        }
        return try fetchSessionInspections(for: backgroundCustomer, userId: userId, in: context).map(\.objectID)
    }
    return try materialize(ids, in: viewContext)
}

/// InspectionItems for one Inspection, unsorted, on the view context the caller passed.
@MainActor
func sessionInspectionItems(
    for inspection: Inspection,
    userId: UUID,
    in viewContext: NSManagedObjectContext
) async throws -> [InspectionItem] {
    let inspectionID = inspection.objectID
    let ids = try await readInBackground(of: viewContext) { context in
        guard let backgroundInspection = try? context.existingObject(with: inspectionID) as? Inspection else {
            throw SessionReadHopError.unresolved
        }
        return try fetchSessionInspectionItems(for: backgroundInspection, userId: userId, in: context).map(\.objectID)
    }
    return try materialize(ids, in: viewContext)
}

private struct HoppedPage: Sendable {
    var ids: [NSManagedObjectID]
    var total: Int
}

private func readInBackground<T: Sendable>(
    of viewContext: NSManagedObjectContext,
    _ body: @escaping (NSManagedObjectContext) throws -> T
) async throws -> T {
    guard let coordinator = viewContext.persistentStoreCoordinator,
          !coordinator.persistentStores.isEmpty else {
        throw SessionReadHopError.storeUnavailable
    }
    let background = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
    background.persistentStoreCoordinator = coordinator
    background.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
    return try await background.perform {
        try body(background)
    }
}

@MainActor
private func materialize<T: NSManagedObject>(
    _ ids: [NSManagedObjectID],
    in viewContext: NSManagedObjectContext
) throws -> [T] {
    try ids.map { id in
        guard let object = try viewContext.existingObject(with: id) as? T else {
            throw SessionReadHopError.unresolved
        }
        return object
    }
}
