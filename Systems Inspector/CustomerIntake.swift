//
//  CustomerIntake.swift
//  Systems Inspector
//

import CoreData

enum CustomerIntake {
    @discardableResult
    static func create(
        form: CustomerFormState,
        in context: NSManagedObjectContext = CoreDataManager.shared.context
    ) -> Customer? {
        guard let userId = UserManager.shared.sessionUserId else { return nil }
        let customer = Customer(context: context)
        customer.id = UUID()
        customer.createdDate = Date()
        customer.userId = userId
        applyFields(customer, form)
        guard save(context) else { return nil }
        return customer
    }

    @discardableResult
    static func update(_ customer: Customer, form: CustomerFormState) -> Bool {
        if customer.userId == nil, let userId = UserManager.shared.sessionUserId {
            customer.userId = userId
        }
        applyFields(customer, form)
        let context = customer.managedObjectContext ?? CoreDataManager.shared.context
        return save(context)
    }

    static func formState(from customer: Customer) -> CustomerFormState {
        CustomerFormState(
            name: customer.name ?? "",
            site: customer.site,
            contactName: customer.contactName,
            phone: customer.phone,
            address: customer.address,
            city: customer.city,
            state: customer.state,
            zipCode: customer.zipCode,
            siteRacking: SiteRacking.from(jsonData: customer.siteRackingJSON),
            siteDocuments: customer.documentFiles()
        )
    }

    private static func applyFields(_ customer: Customer, _ form: CustomerFormState) {
        customer.name = form.name.trimmingCharacters(in: .whitespacesAndNewlines)
        customer.site = trimmed(form.site)
        customer.contactName = trimmed(form.contactName)
        customer.phone = trimmed(form.phone)
        customer.address = trimmed(form.address)
        customer.city = trimmed(form.city)
        customer.state = trimmed(form.state)
        customer.zipCode = trimmed(form.zipCode)
        customer.siteRackingJSON = form.siteRacking.jsonData()
        if let userId = customer.userId {
            customer.replaceDocuments(form.siteDocuments, userId: userId)
        }
    }

    private static func trimmed(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func save(_ context: NSManagedObjectContext) -> Bool {
        if context === CoreDataManager.shared.context {
            return CoreDataManager.shared.saveContext()
        }
        guard context.hasChanges else { return true }
        do {
            try context.save()
            return true
        } catch {
            return false
        }
    }
}
