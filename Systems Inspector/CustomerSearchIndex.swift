import CoreData
import CoreSpotlight
import UniformTypeIdentifiers

enum CustomerSearchIndex {
    static func domainIdentifier(userId: UUID) -> String {
        "customer.\(userId.uuidString)"
    }

    static func itemIdentifier(customerId: UUID) -> String {
        "customer.\(customerId.uuidString)"
    }

    static func customerId(from itemIdentifier: String) -> UUID? {
        let prefix = "customer."
        guard itemIdentifier.hasPrefix(prefix) else { return nil }
        return UUID(uuidString: String(itemIdentifier.dropFirst(prefix.count)))
    }

    static func items(entries: [SessionCustomerSearchEntry], userId: UUID) -> [CSSearchableItem] {
        let domain = domainIdentifier(userId: userId)
        return entries.compactMap { entry in
            let name = entry.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return nil }
            let attributes = CSSearchableItemAttributeSet(contentType: .content)
            attributes.title = name
            attributes.displayName = name
            let site = entry.site.trimmingCharacters(in: .whitespacesAndNewlines)
            if !site.isEmpty {
                attributes.contentDescription = site
            }
            return CSSearchableItem(
                uniqueIdentifier: itemIdentifier(customerId: entry.id),
                domainIdentifier: domain,
                attributeSet: attributes
            )
        }
    }

    static func refreshFromStore() {
        guard CoreDataManager.shared.isStoreLoaded else { return }
        guard UserManager.shared.isUserLoggedIn(), let userId = UserManager.shared.sessionUserId else {
            removeAll()
            return
        }
        guard let entries = try? fetchSessionCustomerSearchEntries(
            userId: userId,
            in: CoreDataManager.shared.context
        ) else { return }
        replace(userId: userId, entries: entries)
    }

    static func replace(
        userId: UUID,
        entries: [SessionCustomerSearchEntry],
        index: CSSearchableIndex = .default()
    ) {
        let domain = domainIdentifier(userId: userId)
        index.deleteSearchableItems(withDomainIdentifiers: [domain]) { _ in
            let searchable = items(entries: entries, userId: userId)
            guard !searchable.isEmpty else { return }
            index.indexSearchableItems(searchable) { _ in }
        }
    }

    static func removeSession(userId: UUID, index: CSSearchableIndex = .default()) {
        index.deleteSearchableItems(withDomainIdentifiers: [domainIdentifier(userId: userId)]) { _ in }
    }

    static func removeAll(index: CSSearchableIndex = .default()) {
        index.deleteAllSearchableItems { _ in }
    }
}
