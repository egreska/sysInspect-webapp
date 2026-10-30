//
//  DeleteAccount.swift
//  Systems Inspector
//

import CoreData
import Foundation

@MainActor
final class DeleteAccount {
    enum Start: Equatable {
        case notSignedIn
        case failed
        case finishing
    }

    static let shared = DeleteAccount(
        cloud: CloudKitAccessCodeClient(),
        context: { CoreDataManager.shared.context },
        defaults: .standard,
        storeLoaded: { CoreDataManager.shared.isStoreLoaded }
    )

    private let cloud: AccessCodeCloudClient
    private let context: () -> NSManagedObjectContext
    private let defaults: UserDefaults
    private let storeLoaded: () -> Bool
    private let clearImageCache: @MainActor () async -> Void
    private var entitlementCache: AccessCodeCache
    private var wipeInProgress = false
    private var rememberedExport: Export?

    private struct Export {
        var started: Date
        var ended: Date?
        var failed: Bool
    }

    init(
        cloud: AccessCodeCloudClient,
        context: @escaping () -> NSManagedObjectContext,
        defaults: UserDefaults,
        storeLoaded: @escaping () -> Bool,
        clearImageCache: (@MainActor () async -> Void)? = nil
    ) {
        self.cloud = cloud
        self.context = context
        self.defaults = defaults
        self.storeLoaded = storeLoaded
        self.entitlementCache = AccessCodeCache(defaults: defaults)
        self.clearImageCache = clearImageCache ?? { await DeleteAccount.clearSharedImageCache() }
    }

    var isUnfinished: Bool {
        DeleteAccountProgressStore.load(defaults) != nil
    }

    func start() async -> Start {
        if let progress = DeleteAccountProgressStore.load(defaults), progress.saved || progress.exportAccepted {
            return .finishing
        }
        guard await cloud.accountAvailable() else { return .notSignedIn }
        return await performWipe(savedAt: nil)
    }

    func noteExport(started: Date, ended: Date?, failed: Bool) async {
        let export = Export(started: started, ended: ended, failed: failed)
        if wipeInProgress {
            if let progress = DeleteAccountProgressStore.load(defaults), covers(export, savedAt: progress.savedAt) {
                rememberedExport = export
            }
            return
        }
        await apply(export)
    }

    func advance() async {
        guard let progress = DeleteAccountProgressStore.load(defaults) else { return }
        if progress.exportAccepted {
            await finishIfCleared()
            return
        }
        guard !progress.saved else { return }
        guard await cloud.accountAvailable() else { return }
        _ = await performWipe(savedAt: progress.savedAt)
    }

    private func performWipe(savedAt explicit: Date?) async -> Start {
        let savedAt = explicit ?? DeleteAccountProgressStore.load(defaults)?.savedAt ?? Date()
        let email = currentEmail()
        wipeInProgress = true
        rememberedExport = nil
        DeleteAccountProgressStore.save(
            DeleteAccountProgress(savedAt: savedAt, saved: false, exportAccepted: false),
            defaults
        )
        let context = context()
        let photoPaths = (try? InspectionItem.itemsWithLocalPhotoFiles(in: context))?
            .flatMap { $0.appOwnedPhotoFilePaths() } ?? []
        guard storeLoaded(), deleteRecords(in: context) else {
            wipeInProgress = false
            rememberedExport = nil
            DeleteAccountProgressStore.save(nil, defaults)
            return .failed
        }
        InspectionItem.removeAppOwnedPhotoFiles(photoPaths)
        clearProfile(email: email)
        UserManager.shared.wipeSession()
        await clearImageCache()
        DeleteAccountProgressStore.save(
            DeleteAccountProgress(savedAt: savedAt, saved: true, exportAccepted: false),
            defaults
        )
        wipeInProgress = false
        if let export = rememberedExport {
            rememberedExport = nil
            await apply(export)
        }
        return .finishing
    }

    private func apply(_ export: Export) async {
        guard var progress = DeleteAccountProgressStore.load(defaults), progress.saved else { return }
        if !progress.exportAccepted {
            guard covers(export, savedAt: progress.savedAt) else { return }
            progress.exportAccepted = true
            DeleteAccountProgressStore.save(progress, defaults)
        }
        await finishIfCleared()
        NotificationCenter.default.post(name: .deleteAccountExportAccepted, object: nil)
    }

    private func finishIfCleared() async {
        guard var entitlement = entitlementCache.load() else { return }
        guard await cloud.clearSessionReady(code: entitlement.code) else { return }
        entitlement.sessionReady = false
        entitlementCache.save(entitlement)
        DeleteAccountProgressStore.save(nil, defaults)
    }

    private func covers(_ export: Export, savedAt: Date) -> Bool {
        guard !export.failed, let ended = export.ended else { return false }
        return export.started >= savedAt && ended >= export.started
    }

    private func currentEmail() -> String? {
        guard let id = UserManager.shared.sessionUserId else { return nil }
        let request: NSFetchRequest<User> = User.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@ AND isActive == YES", id as CVarArg)
        request.fetchLimit = 1
        return try? context().fetch(request).first?.email
    }

    private func deleteRecords(in context: NSManagedObjectContext) -> Bool {
        let names = ["SiteDocument", "InspectionItem", "Inspection", "Customer", "CatalogName", "User"]
        var deleted = false
        context.performAndWait {
            do {
                for name in names {
                    let request = NSFetchRequest<NSManagedObject>(entityName: name)
                    request.includesPropertyValues = false
                    for object in try context.fetch(request) {
                        context.delete(object)
                    }
                }
                if context.hasChanges {
                    try context.save()
                }
                deleted = true
            } catch {
                deleted = false
            }
        }
        return deleted
    }

    private func clearProfile(email: String?) {
        if let email {
            let normalized = email.lowercased()
            defaults.removeObject(forKey: "securityQuestion_\(normalized)")
            defaults.removeObject(forKey: "securityAnswer_\(normalized)")
            defaults.removeObject(forKey: "securityAnswerSalt_\(normalized)")
        }
        ReportNames(defaults: defaults).forget()
    }

    private static func clearSharedImageCache() async {
        ImageCacheManager.shared.clearMemoryCache()
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            ImageCacheManager.shared.clearDiskCache {
                continuation.resume()
            }
        }
    }
}

struct DeleteAccountProgress: Equatable, Codable {
    var savedAt: Date
    var saved: Bool
    var exportAccepted: Bool
}

enum DeleteAccountProgressStore {
    static let key = "deleteAccountUnfinished"

    static func load(_ defaults: UserDefaults = .standard) -> DeleteAccountProgress? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(DeleteAccountProgress.self, from: data)
    }

    static func save(_ progress: DeleteAccountProgress?, _ defaults: UserDefaults = .standard) {
        if let progress, let data = try? JSONEncoder().encode(progress) {
            defaults.set(data, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
}

extension Notification.Name {
    static let deleteAccountExportAccepted = Notification.Name("deleteAccountExportAccepted")
}
