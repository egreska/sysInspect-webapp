//
//  CoreDataManager.swift
//  Systems Inspector
//
//  Created by Eric Greska on 5/22/25.
//

import CoreData
import CloudKit
import UIKit

// Define notification names for Core Data changes
extension Notification.Name {
    static let inspectionCompleted = Notification.Name("InspectionCompleted")
    static let coreDataDidSaveCustomer = Notification.Name("CoreDataDidSaveCustomer")
    static let coreDataDidDeleteCustomer = Notification.Name("CoreDataDidDeleteCustomer")
    static let coreDataDidSaveInspection = Notification.Name("CoreDataDidSaveInspection")
    static let coreDataDidDeleteInspection = Notification.Name("CoreDataDidDeleteInspection")
    static let coreDataDidSaveInspectionItem = Notification.Name("CoreDataDidSaveInspectionItem")
    static let coreDataDidDeleteInspectionItem = Notification.Name("CoreDataDidDeleteInspectionItem")
    static let cloudKitSyncStatusChanged = Notification.Name("CloudKitSyncStatusChanged")
    static let coreDataStoreDidLoad = Notification.Name("CoreDataStoreDidLoad")
    /// Posted when saveContext() fails. userInfo["error"] contains the NSError.
    static let coreDataSaveDidFail = Notification.Name("CoreDataSaveDidFail")
}

extension CoreDataManager {
    
    /// Migrate existing local photos to CloudKit data
    func migrateLocalPhotosToCloudKit() {
        guard isStoreLoaded else {
            print("CoreDataManager: Cannot migrate photos - stores not loaded yet")
            return
        }
        
        // Perform migration on background context to avoid thread safety issues
        performBackgroundTask { backgroundContext in
            do {
                let itemsWithLocalPhotos = try InspectionItem.itemsWithLocalPhotoFiles(in: backgroundContext)
                print("🔄 Found \(itemsWithLocalPhotos.count) items with local photos to migrate")
                
                for item in itemsWithLocalPhotos {
                    item.migrateLocalPhotoToCloudKit()
                }
                
                if !itemsWithLocalPhotos.isEmpty {
                    // Save happens automatically in performBackgroundTask
                    DispatchQueue.main.async {
                        print("✅ Successfully migrated \(itemsWithLocalPhotos.count) photos to CloudKit")
                    }
                }
                
            } catch {
                print("❌ Error migrating local photos: \(error)")
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
    
    // Private initializer to enforce singleton pattern
    private init() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(contextDidSave(_:)),
                                               name: .NSManagedObjectContextDidSave,
                                               object: nil)
        
        // Listen for CloudKit remote change notifications
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(processCloudKitRemoteChanges(_:)),
                                               name: .NSPersistentStoreRemoteChange,
                                               object: nil)
    }
    
    deinit {
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
                    print("CoreDataManager: Error loading persistent store: \(error), \(error.userInfo)")
                    self?.storeLoadingError = error
                    self?.storesLoaded = false
                    
                    // Handle CloudKit specific errors
                    if let ckError = error.userInfo[NSUnderlyingErrorKey] as? CKError {
                        self?.handleCloudKitError(ckError)
                    }
                    
                    #if DEBUG
                    // For development, try to recover by deleting and recreating
                    print("CoreDataManager: Attempting to recover by deleting store...")
                    self?.deleteAndRecreateStore(container: container, storeDescription: storeDescription)
                    #endif
                } else {
                    print("CoreDataManager: Persistent store loaded successfully with CloudKit")
                    self?.storesLoaded = true
                    self?.storeLoadingError = nil
                    
                    // Post notification that stores are ready
                    NotificationCenter.default.post(name: .coreDataStoreDidLoad, object: nil)
                }
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
                    print("CloudKit: Account available")
                    self?.setCloudKitSyncStatus(.succeeded)
                case .noAccount:
                    print("CloudKit: No iCloud account")
                    self?.setCloudKitSyncStatus(.failed(CloudKitError.noAccount))
                case .restricted:
                    print("CloudKit: Account restricted")
                    self?.setCloudKitSyncStatus(.failed(CloudKitError.accountRestricted))
                case .couldNotDetermine:
                    print("CloudKit: Could not determine account status")
                    self?.setCloudKitSyncStatus(.failed(CloudKitError.couldNotDetermine))
                case .temporarilyUnavailable:
                    print("CloudKit: Account temporarily unavailable")
                    self?.setCloudKitSyncStatus(.failed(CloudKitError.temporarilyUnavailable))
                @unknown default:
                    print("CloudKit: Unknown account status")
                    self?.setCloudKitSyncStatus(.failed(CloudKitError.unknown))
                }
            }
        }
    }
    
    private func handleCloudKitError(_ error: CKError) {
        switch error.code {
        case .networkUnavailable, .networkFailure:
            print("CloudKit: Network error - \(error.localizedDescription)")
            setCloudKitSyncStatus(.failed(error))
        case .quotaExceeded:
            print("CloudKit: Quota exceeded - \(error.localizedDescription)")
            setCloudKitSyncStatus(.failed(error))
        case .limitExceeded:
            print("CloudKit: Limit exceeded - \(error.localizedDescription)")
            setCloudKitSyncStatus(.failed(error))
        case .requestRateLimited:
            print("CloudKit: Request rate limited - \(error.localizedDescription)")
            setCloudKitSyncStatus(.failed(error))
        default:
            print("CloudKit: Other error - \(error.localizedDescription)")
            setCloudKitSyncStatus(.failed(error))
        }
    }
    
    @objc private func processCloudKitRemoteChanges(_ notification: Notification) {
        print("CloudKit: Processing remote changes")
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
            print("CoreDataManager: Cannot save - stores not loaded yet")
            if let error = storeLoadingError {
                print("CoreDataManager: Store loading error: \(error)")
            }
            return false
        }
        
        guard context.hasChanges else {
            return true
        }
        
        do {
            setCloudKitSyncStatus(.inProgress)
            try context.save()
            print("CoreDataManager: Context saved successfully")
            setCloudKitSyncStatus(.succeeded)
            return true
        } catch {
            let nserror = error as NSError
            print("CoreDataManager: Save error \(nserror), \(nserror.userInfo)")
            setCloudKitSyncStatus(.failed(nserror))
            
            // Handle specific CloudKit errors
            if let ckError = nserror.userInfo[NSUnderlyingErrorKey] as? CKError {
                handleCloudKitError(ckError)
            }
            
            // Handle validation errors
            if nserror.code == NSValidationMultipleErrorsError,
               let detailedErrors = nserror.userInfo[NSDetailedErrorsKey] as? [NSError] {
                for detailedError in detailedErrors {
                    print("Validation error: \(detailedError.localizedDescription)")
                }
            }
            
            // Rollback changes on error to prevent corruption
            context.rollback()
            print("CoreDataManager: Rolled back changes due to save error")
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
            print("CoreDataManager: Cannot delete - stores not loaded yet")
            return false
        }
        
        context.delete(object)
        return saveContext()
    }
    
    // MARK: - Observers
    @objc private func contextDidSave(_ notification: Notification) {
        guard let savedContext = notification.object as? NSManagedObjectContext else { return }
        
        let insertedObjects = notification.userInfo?[NSInsertedObjectsKey] as? Set<NSManagedObject> ?? Set()
        let updatedObjects = notification.userInfo?[NSUpdatedObjectsKey] as? Set<NSManagedObject> ?? Set()
        let deletedObjects = notification.userInfo?[NSDeletedObjectsKey] as? Set<NSManagedObject> ?? Set()
        
        print("CoreDataManager: Received NSManagedObjectContextDidSaveNotification from context: \(savedContext.description)")
        
        DispatchQueue.main.async {
            self.context.perform {
                self.postChangeNotifications(insertedObjects: insertedObjects, updatedObjects: updatedObjects, deletedObjects: deletedObjects)
            }
        }
    }
    
    private func postChangeNotifications(insertedObjects: Set<NSManagedObject>, updatedObjects: Set<NSManagedObject>, deletedObjects: Set<NSManagedObject>) {
        print("📢 Processing Core Data changes for notifications (inserted: \(insertedObjects.count), updated: \(updatedObjects.count), deleted: \(deletedObjects.count))...")
        
        // Handle inserted and updated objects
        for object in insertedObjects.union(updatedObjects) {
            if let customer = object as? Customer {
                print("📢 Posting notification for saved customer: \(customer.name ?? "N/A"), userId: \(customer.userId?.uuidString ?? "nil")")
                NotificationCenter.default.post(name: .coreDataDidSaveCustomer, object: nil, userInfo: ["object": customer])
            } else if let inspection = object as? Inspection {
                print("📢 Posting notification for saved inspection: \(inspection.id?.uuidString ?? "N/A"), userId: \(inspection.userId?.uuidString ?? "nil")")
                NotificationCenter.default.post(name: .coreDataDidSaveInspection, object: nil, userInfo: ["object": inspection])
            } else if let item = object as? InspectionItem {
                print("📢 Posting notification for saved inspection item: \(item.id?.uuidString ?? "N/A"), userId: \(item.userId?.uuidString ?? "nil")")
                NotificationCenter.default.post(name: .coreDataDidSaveInspectionItem, object: nil, userInfo: ["object": item])
            }
        }
        
        // Handle deleted objects
        for object in deletedObjects {
            let objectID = object.objectID
            let entityName = object.entity.name
            
            if let entityName = entityName {
                switch entityName {
                case "Customer":
                    print("📢 Posting notification for deleted customer ID: \(objectID.uriRepresentation().lastPathComponent)")
                    NotificationCenter.default.post(name: .coreDataDidDeleteCustomer, object: nil, userInfo: ["id": objectID])
                case "Inspection":
                    print("📢 Posting notification for deleted inspection ID: \(objectID.uriRepresentation().lastPathComponent)")
                    NotificationCenter.default.post(name: .coreDataDidDeleteInspection, object: nil, userInfo: ["id": objectID])
                case "InspectionItem":
                    print("📢 Posting notification for deleted inspection item ID: \(objectID.uriRepresentation().lastPathComponent)")
                    NotificationCenter.default.post(name: .coreDataDidDeleteInspectionItem, object: nil, userInfo: ["id": objectID])
                default:
                    break
                }
            }
        }
    }
    
    // MARK: - Background Context
    func backgroundContext() -> NSManagedObjectContext {
        let backgroundContext = persistentContainer.newBackgroundContext()
        backgroundContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        return backgroundContext
    }
    
    func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        guard isStoreLoaded else {
            print("CoreDataManager: Cannot perform background task - stores not loaded yet")
            return
        }
        
        let context = backgroundContext()
        context.perform {
            block(context)
            
            if context.hasChanges {
                do {
                    try context.save()
                    print("CoreDataManager: Background context saved")
                } catch {
                    print("CoreDataManager: Background save error \(error)")
                }
            }
        }
    }
    
    // MARK: - Data Migration
    func migrateStoreIfNeeded(completion: @escaping (Bool) -> Void) {
        completion(true)
    }
    
    // MARK: - Utility Methods
    func fetch<T: NSManagedObject>(_ request: NSFetchRequest<T>) -> [T] {
        guard isStoreLoaded else {
            print("CoreDataManager: Cannot fetch - stores not loaded yet")
            return []
        }
        
        do {
            return try context.fetch(request)
        } catch {
            print("Failed to fetch \(T.entity().name ?? "Unknown Entity"): \(error)")
            return []
        }
    }
    
    func count<T: NSManagedObject>(_ request: NSFetchRequest<T>) -> Int {
        guard isStoreLoaded else {
            print("CoreDataManager: Cannot count - stores not loaded yet")
            return 0
        }
        
        do {
            return try context.count(for: request)
        } catch {
            print("Failed to count \(T.entity().name ?? "Unknown Entity"): \(error)")
            return 0
        }
    }
    
    func createCompoundPredicate(predicates: [NSPredicate]) -> NSPredicate {
        return NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }
    
    // MARK: - Database Backup
    func backupDatabase() -> URL? {
        guard isStoreLoaded else {
            print("CoreDataManager: Cannot backup - stores not loaded yet")
            return nil
        }
        
        guard let storeURL = persistentContainer.persistentStoreDescriptions.first?.url else {
            return nil
        }
        
        let fileManager = FileManager.default
        let backupURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Systems_Inspector_backup_\(Date().timeIntervalSince1970).sqlite")
        
        do {
            try fileManager.copyItem(at: storeURL, to: backupURL)
            return backupURL
        } catch {
            print("Failed to backup database: \(error)")
            return nil
        }
    }
    
    // MARK: - Development helpers
    #if DEBUG
    func resetAllData() {
        guard isStoreLoaded else {
            print("CoreDataManager: Cannot reset data - stores not loaded yet")
            return
        }
        
        let entities = ["Customer", "Inspection", "InspectionItem", "User"]
        
        for entityName in entities {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            
            do {
                try context.execute(deleteRequest)
                print("Deleted all \(entityName) entities")
            } catch {
                print("Failed to delete \(entityName) entities: \(error)")
            }
        }
        
        saveContext()
    }
    
    private func deleteAndRecreateStore(container: NSPersistentCloudKitContainer, storeDescription: NSPersistentStoreDescription) {
        guard let storeURL = storeDescription.url else { return }
        
        do {
            try container.persistentStoreCoordinator.destroyPersistentStore(at: storeURL, ofType: NSSQLiteStoreType, options: nil)
            try FileManager.default.removeItem(at: storeURL)
            print("Deleted and recreating store")
            
            container.loadPersistentStores { [weak self] (_, error) in
                DispatchQueue.main.async {
                    if let error = error {
                        print("Error recreating store: \(error)")
                        self?.storesLoaded = false
                        self?.storeLoadingError = error
                    } else {
                        print("Store recreated successfully")
                        self?.storesLoaded = true
                        self?.storeLoadingError = nil
                        NotificationCenter.default.post(name: .coreDataStoreDidLoad, object: nil)
                    }
                }
            }
        } catch {
            print("Error deleting store: \(error)")
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
