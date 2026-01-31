//
//  UserManager.swift
//  Systems Inspector
//
//  Created by Eric Greska on 5/25/25.
//

import Foundation
import CoreData
import CryptoKit

class UserManager {
    static let shared = UserManager()
    
    private init() {}
    
    // MARK: - User Creation
    func createUser(email: String, password: String) -> Bool {
        let context = CoreDataManager.shared.context
        
        // Check if user already exists
        if userExists(email: email) {
            return false
        }
        
        // Create new user
        let user = User(context: context)
        user.id = UUID()
        user.email = email.lowercased()
        user.passwordHash = hashPassword(password)
        user.createdDate = Date()
        user.isActive = true
        
        // Save to Core Data
        do {
            try context.save()
            return true
        } catch {
            print("Error creating user: \(error)")
            return false
        }
    }
    
    // MARK: - User Authentication
    func authenticateUser(email: String, password: String) -> Bool {
        let context = CoreDataManager.shared.context
        let fetchRequest: NSFetchRequest<User> = User.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "email == %@ AND isActive == YES", email.lowercased())
        
        do {
            let users = try context.fetch(fetchRequest)
            if let user = users.first {
                let hashedPassword = hashPassword(password)
                if user.passwordHash == hashedPassword {
                    // Update last login date
                    user.lastLoginDate = Date()
                    try context.save()
                    
                    // Store current user session
                    UserDefaults.standard.set(user.email, forKey: "currentUserEmail")
                    UserDefaults.standard.set(true, forKey: "isLoggedIn")
                    
                    return true
                }
            }
        } catch {
            print("Error authenticating user: \(error)")
        }
        
        return false
    }
    
    // MARK: - User Queries
    func userExists(email: String) -> Bool {
        let context = CoreDataManager.shared.context
        let fetchRequest: NSFetchRequest<User> = User.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "email == %@", email.lowercased())
        
        do {
            let count = try context.count(for: fetchRequest)
            return count > 0
        } catch {
            print("Error checking if user exists: \(error)")
            return false
        }
    }
    
    func getCurrentUser() -> User? {
        guard let email = UserDefaults.standard.string(forKey: "currentUserEmail") else {
            return nil
        }
        
        let context = CoreDataManager.shared.context
        let fetchRequest: NSFetchRequest<User> = User.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "email == %@ AND isActive == YES", email)
        
        do {
            let users = try context.fetch(fetchRequest)
            return users.first
        } catch {
            print("Error fetching current user: \(error)")
            return nil
        }
    }
    
    // MARK: - Session Management
    func isUserLoggedIn() -> Bool {
        return UserDefaults.standard.bool(forKey: "isLoggedIn")
    }
    
    func logoutUser() {
        UserDefaults.standard.removeObject(forKey: "currentUserEmail")
        UserDefaults.standard.set(false, forKey: "isLoggedIn")
    }
    
    // MARK: - Password Helpers
    private func hashPassword(_ password: String) -> String {
        let inputData = Data(password.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    // MARK: - User Management
    func getAllUsers() -> [User] {
        let context = CoreDataManager.shared.context
        let fetchRequest: NSFetchRequest<User> = User.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdDate", ascending: false)]
        
        do {
            return try context.fetch(fetchRequest)
        } catch {
            print("Error fetching users: \(error)")
            return []
        }
    }
    
    func deleteUser(email: String) -> Bool {
        let context = CoreDataManager.shared.context
        let fetchRequest: NSFetchRequest<User> = User.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "email == %@", email.lowercased())
        
        do {
            let users = try context.fetch(fetchRequest)
            if let user = users.first {
                context.delete(user)
                try context.save()
                return true
            }
        } catch {
            print("Error deleting user: \(error)")
        }
        
        return false
    }
    
    func changePassword(email: String, oldPassword: String, newPassword: String) -> Bool {
        let context = CoreDataManager.shared.context
        let fetchRequest: NSFetchRequest<User> = User.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "email == %@ AND isActive == YES", email.lowercased())
        
        do {
            let users = try context.fetch(fetchRequest)
            if let user = users.first {
                let oldHashedPassword = hashPassword(oldPassword)
                if user.passwordHash == oldHashedPassword {
                    user.passwordHash = hashPassword(newPassword)
                    try context.save()
                    return true
                }
            }
        } catch {
            print("Error changing password: \(error)")
        }
        
        return false
    }
}
