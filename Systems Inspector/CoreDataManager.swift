//
//  CoreDataManager.swift
//  Systems Inspector
//
//  Created by Eric Greska on 5/22/25.
//

import CoreData
import CloudKit
import SQLite3
import UIKit

private func coreDataLog(_ message: @autoclosure () -> String) {
    #if DEBUG
    Swift.print(message())
    #endif
}

func copySQLiteStore(from storeURL: URL, to backupURL: URL) throws {
    var source: OpaquePointer?
    var destination: OpaquePointer?
    defer {
        sqlite3_close(source)
        sqlite3_close(destination)
    }
    guard sqlite3_open_v2(storeURL.path, &source, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
        throw storeCopyError(source, fallback: "Could not open the database.")
    }
    guard sqlite3_open_v2(backupURL.path, &destination, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil) == SQLITE_OK else {
        throw storeCopyError(destination, fallback: "Could not create the backup.")
    }
    guard let backup = sqlite3_backup_init(destination, "main", source, "main") else {
        throw storeCopyError(destination, fallback: "Could not copy the database.")
    }
    let step = sqlite3_backup_step(backup, -1)
    sqlite3_backup_finish(backup)
    guard step == SQLITE_DONE else {
        throw storeCopyError(destination, fallback: "Could not finish the backup.")
    }
    sqlite3_exec(destination, "PRAGMA journal_mode=DELETE", nil, nil, nil)
    sqlite3_close(destination)
    destination = nil
    sqlite3_close(source)
    source = nil
    let fileManager = FileManager.default
    try? fileManager.removeItem(at: URL(fileURLWithPath: backupURL.path + "-wal"))
    try? fileManager.removeItem(at: URL(fileURLWithPath: backupURL.path + "-shm"))
}

private func storeCopyError(_ db: OpaquePointer?, fallback: String) -> NSError {
    let message = db.map { String(cString: sqlite3_errmsg($0)) } ?? fallback
    return NSError(domain: "StoreCopy", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
}

// Define notification names for Core Data changes
extension Notification.Name {
    static let inspectionCompleted = Notification.Name("InspectionCompleted")
    static let cloudKitSyncStatusChanged = Notification.Name("CloudKitSyncStatusChanged")
    static let coreDataStoreDidLoad = Notification.Name("CoreDataStoreDidLoad")
    /// Posted when saveContext() fails. userInfo["error"] contains the NSError.
    static let coreDataSaveDidFail = Notification.Name("CoreDataSaveDidFail")
}

extension CoreDataManager {
    
    /// Migrate existing local photos to CloudKit data
    func migrateLocalPhotosToCloudKit() {
        guard isStoreLoaded else {
            coreDataLog("CoreDataManager: Cannot migrate photos - stores not loaded yet")
            return
        }
        
        // Perform migration on background context to avoid thread safety issues
        performBackgroundTask { backgroundContext in
            do {
                let itemsWithLocalPhotos = try InspectionItem.itemsWithLocalPhotoFiles(in: backgroundContext)
                coreDataLog("🔄 Found \(itemsWithLocalPhotos.count) items with local photos to migrate")
                
                let paths = itemsWithLocalPhotos.flatMap { $0.migrateLocalPhotoToCloudKit() }
                if backgroundContext.hasChanges {
                    try backgroundContext.save()
                }
                InspectionItem.removeAppOwnedPhotoFiles(paths)
                
            } catch {
                backgroundContext.rollback()
                coreDataLog("❌ Error migrating local photos: \(error)")
            }
        }
    }
}

class CoreDataManager {
    static let shared = CoreDataManager()
    
    // CloudKit sync status
    enum CloudKitSyncStatus {
        case notStarted
        case inProgress
        case succeeded
        case failed(Error)
    }
    
    private var cloudKitSyncStatus: CloudKitSyncStatus = .notStarted {
        didSet {
            NotificationCenter.default.post(name: .cloudKitSyncStatusChanged, object: cloudKitSyncStatus)
        }
    }

    /// NSPersistentStoreRemoteChange and other callbacks can run off the main thread; UI observers must receive sync status on the main queue.
    private func setCloudKitSyncStatus(_ status: CloudKitSyncStatus) {
        if Thread.isMainThread {
            cloudKitSyncStatus = status
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.cloudKitSyncStatus = status
            }
        }
    }
    
    // Store loading status
    private var storesLoaded = false
    private var storeLoadingError: Error?
    private var deleteExportObserver: NSObjectProtocol?
    
    // Private initializer to enforce singleton pattern
    private init() {
        // Listen for CloudKit remote change notifications
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(processCloudKitRemoteChanges(_:)),
                                               name: .NSPersistentStoreRemoteChange,
                                               object: nil)
    }
    
    deinit {
        if let deleteExportObserver {
            NotificationCenter.default.removeObserver(deleteExportObserver)
        }
        NotificationCenter.default.removeObserver(self)
    }
    
    /// Current CloudKit sync status for display in Settings.
    var currentCloudKitSyncStatus: CloudKitSyncStatus {
        cloudKitSyncStatus
    }
    
    // MARK: - Core Data stack with CloudKit
    lazy var persistentContainer: NSPersistentCloudKitContainer = {
        let container = NSPersistentCloudKitContainer(name: "Systems_Inspector")
        
        // Configure for CloudKit
        let storeDescription = container.persistentStoreDescriptions.first
        storeDescription?.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        storeDescription?.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        // Add lightweight migration options
        storeDescription?.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
        storeDescription?.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
        storeDescription?.shouldAddStoreAsynchronously = true
        
        container.loadPersistentStores { [weak self] (storeDescription, error) in
            DispatchQueue.main.async {
                if let error = error as NSError? {
                    coreDataLog("CoreDataManager: Error loading persistent store: \(error), \(error.userInfo)")
                    self?.storeLoadingError = error
                    self?.storesLoaded = false
                    
                    // Handle CloudKit specific errors
                    if let ckError = error.userInfo[NSUnderlyingErrorKey] as? CKError {
                        self?.handleCloudKitError(ckError)
                    }
                    
                    #if DEBUG
                    // For development, try to recover by deleting and recreating
                    coreDataLog("CoreDataManager: Attempting to recover by deleting store...")
                    self?.deleteAndRecreateStore(container: container, storeDescription: storeDescription)
                    #endif
                } else {
                    coreDataLog("CoreDataManager: Persistent store loaded successfully with CloudKit")
                    self?.storesLoaded = true
                    self?.storeLoadingError = nil
                    
                    // Post notification that stores are ready
                    NotificationCenter.default.post(name: .coreDataStoreDidLoad, object: nil)
                }
            }
        }
        
        deleteExportObserver = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: container,
            queue: .main
        ) { note in
            guard let event = note.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey] as? NSPersistentCloudKitContainer.Event else { return }
            guard event.type == .export else { return }
            Task { @MainActor in
                await DeleteAccount.shared.noteExport(
                    started: event.startDate,
                    ended: event.endDate,
                    failed: event.error != nil
                )
            }
        }

        // Configure contexts
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        
        return container
    }()
    
    // MARK: - Core Data context
    var context: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    // MARK: - Store Status Methods
    
    /// Check if persistent stores are loaded and ready
    var isStoreLoaded: Bool {
        return storesLoaded && storeLoadingError == nil
    }
    
    /// Wait for stores to load (with timeout)
    func waitForStoreToLoad(timeout: TimeInterval = 10.0, completion: @escaping (Bool) -> Void) {
        if isStoreLoaded {
            completion(true)
            return
        }

        if storeLoadingError != nil {
            completion(false)
            return
        }

        let notificationCenter = NotificationCenter.default
        
        // Use a class to hold the observer to avoid mutation after capture
        class ObserverHolder {
            var observer: NSObjectProtocol?
            var timer: Timer?
            var finished = false

            func finish(_ ready: Bool, completion: @escaping (Bool) -> Void) {
                guard !finished else { return }
                finished = true
                timer?.invalidate()
                if let observer {
                    NotificationCenter.default.removeObserver(observer)
                }
                completion(ready)
            }
        }
        
        let holder = ObserverHolder()
        
        holder.timer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { _ in
            holder.finish(false, completion: completion)
        }
        
        holder.observer = notificationCenter.addObserver(forName: .coreDataStoreDidLoad, object: nil, queue: .main) { [weak self] _ in
            holder.finish(self?.isStoreLoaded == true, completion: completion)
        }

        // Trigger lazy loading if not already started
        _ = persistentContainer
        if isStoreLoaded {
            holder.finish(true, completion: completion)
        }
    }

    // MARK: - CloudKit Methods
    
    func checkCloudKitStatus() {
        CKContainer(identifier: "iCloud.SysInspectDB").accountStatus { [weak self] (status, error) in
            DispatchQueue.main.async {
                switch status {
                case .available:
                    coreDataLog("CloudKit: Account available")
                    self?.setCloudKitSyncStatus(.succeeded)
                case .noAccount:
                    coreDataLog("CloudKit: No iCloud account")
                    self?.setCloudKitSyncStatus(.failed(CloudKitError.noAccount))
                case .restricted:
                    coreDataLog("CloudKit: Account restricted")
                    self?.setCloudKitSyncStatus(.failed(CloudKitError.accountRestricted))
                case .couldNotDetermine:
                    coreDataLog("CloudKit: Could not determine account status")
                    self?.setCloudKitSyncStatus(.failed(CloudKitError.couldNotDetermine))
                case .temporarilyUnavailable:
                    coreDataLog("CloudKit: Account temporarily unavailable")
                    self?.setCloudKitSyncStatus(.failed(CloudKitError.temporarilyUnavailable))
                @unknown default:
                    coreDataLog("CloudKit: Unknown account status")
                    self?.setCloudKitSyncStatus(.failed(CloudKitError.unknown))
                }
            }
        }
    }
    
    private func handleCloudKitError(_ error: CKError) {
        switch error.code {
        case .networkUnavailable, .networkFailure:
            coreDataLog("CloudKit: Network error - \(error.localizedDescription)")
            setCloudKitSyncStatus(.failed(error))
        case .quotaExceeded:
            coreDataLog("CloudKit: Quota exceeded - \(error.localizedDescription)")
            setCloudKitSyncStatus(.failed(error))
        case .limitExceeded:
            coreDataLog("CloudKit: Limit exceeded - \(error.localizedDescription)")
            setCloudKitSyncStatus(.failed(error))
        case .requestRateLimited:
            coreDataLog("CloudKit: Request rate limited - \(error.localizedDescription)")
            setCloudKitSyncStatus(.failed(error))
        default:
            coreDataLog("CloudKit: Other error - \(error.localizedDescription)")
            setCloudKitSyncStatus(.failed(error))
        }
    }
    
    @objc private func processCloudKitRemoteChanges(_ notification: Notification) {
        coreDataLog("CloudKit: Processing remote changes")
        // Run entirely on the view context queue (main). Do not mix `DispatchQueue.main.async`
        // (inProgress) with `context.perform` (succeeded): two main-queue blocks can reorder and
        // fire duplicate UI updates during UIImageView/tint traversal (Crashlytics: objc_loadWeak).
        context.perform {
            self.setCloudKitSyncStatus(.succeeded)
        }
    }
    
    // MARK: - Core Data operations
    /// Saves the view context. Returns true if save succeeded or there were no changes; false on failure.
    @discardableResult
    func saveContext() -> Bool {
        guard isStoreLoaded else {
            coreDataLog("CoreDataManager: Cannot save - stores not loaded yet")
            if let error = storeLoadingError {
                coreDataLog("CoreDataManager: Store loading error: \(error)")
            }
            return false
        }
        
        guard context.hasChanges else {
            return true
        }
        
        do {
            setCloudKitSyncStatus(.inProgress)
            try context.save()
            coreDataLog("CoreDataManager: Context saved successfully")
            setCloudKitSyncStatus(.succeeded)
            return true
        } catch {
            let nserror = error as NSError
            coreDataLog("CoreDataManager: Save error \(nserror), \(nserror.userInfo)")
            setCloudKitSyncStatus(.failed(nserror))
            
            // Handle specific CloudKit errors
            if let ckError = nserror.userInfo[NSUnderlyingErrorKey] as? CKError {
                handleCloudKitError(ckError)
            }
            
            // Handle validation errors
            if nserror.code == NSValidationMultipleErrorsError,
               let detailedErrors = nserror.userInfo[NSDetailedErrorsKey] as? [NSError] {
                for detailedError in detailedErrors {
                    coreDataLog("Validation error: \(detailedError.localizedDescription)")
                }
            }
            
            // Rollback changes on error to prevent corruption
            context.rollback()
            coreDataLog("CoreDataManager: Rolled back changes due to save error")
            NotificationCenter.default.post(name: .coreDataSaveDidFail, object: nil, userInfo: ["error": nserror])
            
            #if DEBUG
            // In debug mode, we want to know about errors but not crash the app
            assertionFailure("Core Data save failed: \(nserror), \(nserror.userInfo)")
            #endif
            return false
        }
    }
    
    /// Deletes the object and saves. Returns true if delete and save succeeded; false otherwise.
    @discardableResult
    func deleteObject(_ object: NSManagedObject) -> Bool {
        guard isStoreLoaded else {
            coreDataLog("CoreDataManager: Cannot delete - stores not loaded yet")
            return false
        }
        
        context.delete(object)
        return saveContext()
    }
    
    // MARK: - Background Context
    func backgroundContext() -> NSManagedObjectContext {
        let backgroundContext = persistentContainer.newBackgroundContext()
        backgroundContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        return backgroundContext
    }
    
    func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        guard isStoreLoaded else {
            coreDataLog("CoreDataManager: Cannot perform background task - stores not loaded yet")
            return
        }
        
        let context = backgroundContext()
        context.perform {
            block(context)
            
            if context.hasChanges {
                do {
                    try context.save()
                    coreDataLog("CoreDataManager: Background context saved")
                } catch {
                    coreDataLog("CoreDataManager: Background save error \(error)")
                }
            }
        }
    }
    
    // MARK: - Utility Methods
    func fetch<T: NSManagedObject>(_ request: NSFetchRequest<T>) -> [T] {
        guard isStoreLoaded else {
            coreDataLog("CoreDataManager: Cannot fetch - stores not loaded yet")
            return []
        }
        
        do {
            return try context.fetch(request)
        } catch {
            coreDataLog("Failed to fetch \(T.entity().name ?? "Unknown Entity"): \(error)")
            return []
        }
    }
    
    func count<T: NSManagedObject>(_ request: NSFetchRequest<T>) -> Int {
        guard isStoreLoaded else {
            coreDataLog("CoreDataManager: Cannot count - stores not loaded yet")
            return 0
        }
        
        do {
            return try context.count(for: request)
        } catch {
            coreDataLog("Failed to count \(T.entity().name ?? "Unknown Entity"): \(error)")
            return 0
        }
    }
    
    func createCompoundPredicate(predicates: [NSPredicate]) -> NSPredicate {
        return NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }
    
    // MARK: - Database Backup
    func backupDatabase() -> URL? {
        guard isStoreLoaded else {
            coreDataLog("CoreDataManager: Cannot backup - stores not loaded yet")
            return nil
        }
        
        guard let storeURL = persistentContainer.persistentStoreDescriptions.first?.url else {
            return nil
        }
        
        let fileManager = FileManager.default
        let backupURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Systems_Inspector_backup_\(Date().timeIntervalSince1970).sqlite")

        do {
            try copySQLiteStore(from: storeURL, to: backupURL)
            return backupURL
        } catch {
            try? fileManager.removeItem(at: backupURL)
            coreDataLog("Failed to backup database: \(error)")
            return nil
        }
    }
    
    // MARK: - Development helpers
    #if DEBUG
    func resetAllData() {
        guard isStoreLoaded else {
            coreDataLog("CoreDataManager: Cannot reset data - stores not loaded yet")
            return
        }
        
        let entities = ["Customer", "Inspection", "InspectionItem", "User"]
        
        for entityName in entities {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            
            do {
                try context.execute(deleteRequest)
                coreDataLog("Deleted all \(entityName) entities")
            } catch {
                coreDataLog("Failed to delete \(entityName) entities: \(error)")
            }
        }
        
        saveContext()
    }
    
    private func deleteAndRecreateStore(container: NSPersistentCloudKitContainer, storeDescription: NSPersistentStoreDescription) {
        guard let storeURL = storeDescription.url else { return }
        
        do {
            try container.persistentStoreCoordinator.destroyPersistentStore(at: storeURL, ofType: NSSQLiteStoreType, options: nil)
            try FileManager.default.removeItem(at: storeURL)
            coreDataLog("Deleted and recreating store")
            
            container.loadPersistentStores { [weak self] (_, error) in
                DispatchQueue.main.async {
                    if let error = error {
                        coreDataLog("Error recreating store: \(error)")
                        self?.storesLoaded = false
                        self?.storeLoadingError = error
                    } else {
                        coreDataLog("Store recreated successfully")
                        self?.storesLoaded = true
                        self?.storeLoadingError = nil
                        NotificationCenter.default.post(name: .coreDataStoreDidLoad, object: nil)
                    }
                }
            }
        } catch {
            coreDataLog("Error deleting store: \(error)")
        }
    }
    #endif
}

// MARK: - CloudKit Error Types
enum CloudKitError: Error, LocalizedError {
    case noAccount
    case accountRestricted
    case couldNotDetermine
    case temporarilyUnavailable
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .noAccount:
            return "No iCloud account is available. Please sign in to iCloud in Settings."
        case .accountRestricted:
            return "iCloud account is restricted."
        case .couldNotDetermine:
            return "Could not determine iCloud account status."
        case .temporarilyUnavailable:
            return "iCloud account is temporarily unavailable."
        case .unknown:
            return "Unknown iCloud error."
        }
    }
}

// MARK: - CloudKit Sync Status Display
extension CoreDataManager.CloudKitSyncStatus {
    var displayString: String {
        switch self {
        case .notStarted: return "Not started"
        case .inProgress: return "Syncing…"
        case .succeeded: return "Active"
        case .failed: return "Paused – tap to open Settings"
        }
    }
}
