//
//  SessionSecretStore.swift
//  Systems Inspector
//

import Foundation
import Security

enum SessionSecretRules {
    static let iterations = 100_000

    static func normalizedAnswer(_ answer: String) -> String {
        answer.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum SessionSecretMessage {
    static let waitingTitle = "Password Not on This iPad"
    static let waiting = "This iPad does not have the password for this account yet. Turn on iCloud Keychain, or open the iPad that set the password."
}

struct SessionSecret: Codable, Equatable {
    var passwordHash: String?
    var passwordSalt: Data?
    var passwordIterations: Int?
    var securityQuestion: String?
    var securityAnswerHash: String?
    var securityAnswerSalt: Data?
    var securityAnswerIterations: Int?

    var hasPassword: Bool {
        passwordHash != nil
    }

    var hasSecurityAnswer: Bool {
        securityAnswerHash != nil || securityQuestion != nil
    }
}

protocol SessionSecretStore: AnyObject {
    func load(userId: UUID) -> SessionSecret?
    func save(_ secret: SessionSecret, userId: UUID) -> Bool
    func delete(userId: UUID)
}

final class MemorySessionSecretStore: SessionSecretStore {
    private var items: [UUID: SessionSecret] = [:]

    func load(userId: UUID) -> SessionSecret? {
        items[userId]
    }

    func save(_ secret: SessionSecret, userId: UUID) -> Bool {
        items[userId] = secret
        return true
    }

    func delete(userId: UUID) {
        items[userId] = nil
    }
}

final class KeychainSessionSecretStore: SessionSecretStore {
    static let service = "SystemsInspector.SessionSecret"

    func load(userId: UUID) -> SessionSecret? {
        var query = baseQuery(userId: userId)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return try? JSONDecoder().decode(SessionSecret.self, from: data)
    }

    func save(_ secret: SessionSecret, userId: UUID) -> Bool {
        guard let data = try? JSONEncoder().encode(secret) else { return false }
        let query = baseQuery(userId: userId) as CFDictionary
        let existing = SecItemCopyMatching(query, nil)
        if existing == errSecSuccess {
            let attributes = [kSecValueData as String: data] as CFDictionary
            return SecItemUpdate(query, attributes) == errSecSuccess
        }
        var insert = baseQuery(userId: userId)
        insert[kSecValueData as String] = data
        insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        return SecItemAdd(insert as CFDictionary, nil) == errSecSuccess
    }

    func delete(userId: UUID) {
        SecItemDelete(baseQuery(userId: userId) as CFDictionary)
    }

    private func baseQuery(userId: UUID) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: userId.uuidString,
            kSecAttrSynchronizable as String: kCFBooleanTrue as Any
        ]
    }
}
