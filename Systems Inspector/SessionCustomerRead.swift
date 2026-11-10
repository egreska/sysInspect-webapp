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
