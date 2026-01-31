//
//  CoreDataManager.swift
//  Systems Inspector
//
//  Created by Eric Greska on 5/22/25.
//
import CoreData

class CoreDataManager {
    static let shared = CoreDataManager()
    
    // Private initializer to enforce singleton pattern
    private init() {}
    
    // MARK: - Core Data stack
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "Systems_Inspector")
        
        // Add this line to enable lightweight migration
        let description = container.persistentStoreDescriptions.first
        description?.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
        description?.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
        
        container.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate.
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        
        // For better performance when reading data
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        return container
    }()
    
    // MARK: - Core Data context
    var context: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    // MARK: - Core Data operations
    func saveContext() {
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nserror = error as NSError
                print("Unresolved error \(nserror), \(nserror.userInfo)")
                #if DEBUG
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
                #endif
            }
        }
    }
    
    // Creates a new background context for performing operations off the main thread
    func backgroundContext() -> NSManagedObjectContext {
        let backgroundContext = persistentContainer.newBackgroundContext()
        backgroundContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return backgroundContext
    }
    
    // Perform a task on a background context and save
    func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        let context = backgroundContext()
        context.perform {
            block(context)
            
            if context.hasChanges {
                do {
                    try context.save()
                } catch {
                    let nserror = error as NSError
                    print("Background save error \(nserror), \(nserror.userInfo)")
                }
            }
        }
    }
    
    func batchDelete<T: NSManagedObject>(entity: T.Type, predicate: NSPredicate) {
        let request = NSBatchDeleteRequest(fetchRequest: NSFetchRequest<NSFetchRequestResult>(entityName: String(describing: entity)))
        request.resultType = .resultTypeObjectIDs
        
        do {
            let result = try context.execute(request) as? NSBatchDeleteResult
            let objectIDArray = result?.result as? [NSManagedObjectID]
            let changes = [NSDeletedObjectsKey: objectIDArray]
            NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes as [AnyHashable : Any], into: [context])
        } catch {
            print("Batch delete failed: \(error)")
        }
    }
    // MARK: - Data Migration
    func migrateStoreIfNeeded(completion: @escaping (Bool) -> Void) {
        // This is where more complex migration logic would go.
        // With NSMigratePersistentStoresAutomaticallyOption and NSInferMappingModelAutomaticallyOption
        // set to true in persistentContainer, lightweight migration is handled automatically.
        // So, this method can simply return true for success if the container loaded successfully.
        
        // If you were to implement custom migration, you'd check for incompatible models
        // and perform manual mapping model steps here.
        
        completion(true) // Assuming automatic migration handles simple cases
    }
    
    // MARK: - Data Reset (for development/testing only)
    func resetAllData() {
        #if DEBUG
        let coordinator = persistentContainer.persistentStoreCoordinator
        guard let storeURL = coordinator.persistentStores.first?.url else {
            print("Error: Could not find persistent store URL.")
            return
        }

        persistentContainer = NSPersistentContainer(name: "Systems_Inspector")
        // Re-add options for lightweight migration to the new container
        let description = persistentContainer.persistentStoreDescriptions.first
        description?.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
        description?.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
        persistentContainer.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }

        // Delete the existing file
        do {
            try FileManager.default.removeItem(at: storeURL)
            print("Successfully deleted old database file.")
        } catch {
            print("Error deleting old database file: \(error)")
        }

        print("All data reset successfully (new container initialized).")

        #endif
    }
    
    // MARK: - Database Backup
    func backupDatabase() -> URL? {
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
    
    // MARK: - Fetch Request Helpers
    
    func fetch<T: NSManagedObject>(_ request: NSFetchRequest<T>) -> [T] {
        do {
            return try context.fetch(request)
        } catch {
            print("Failed to fetch \(T.entity().name ?? "Unknown Entity"): \(error)")
            return []
        }
    }
    
    func count<T: NSManagedObject>(_ request: NSFetchRequest<T>) -> Int {
        do {
            return try context.count(for: request)
        } catch {
            print("Failed to count \(T.entity().name ?? "Unknown Entity"): \(error)")
            return 0
        }
    }
    
    // Helper for creating a predicate with multiple conditions
    func createCompoundPredicate(predicates: [NSPredicate]) -> NSPredicate {
        return NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }
}
