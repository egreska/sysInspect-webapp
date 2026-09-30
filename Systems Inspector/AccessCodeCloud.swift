//
//  AccessCodeCloud.swift
//  Systems Inspector
//

import CloudKit
import Foundation

enum AccessCodeCloudField {
    static let recordType = "AccessCode"
    static let status = "status"
    static let claimedUserRecordName = "claimedUserRecordName"
    static let claimedAt = "claimedAt"
    static let sessionReady = "sessionReady"
    static let issued = "issued"
    static let claimed = "claimed"
    static let retired = "retired"
}

protocol AccessCodeCloudClient {
    func accountAvailable() async -> Bool
    func userRecordName() async -> String?
    func fetch(code: String) async -> AccessCodeRecordState
    func claim(code: String, userRecordName: String) async -> Bool
    func markSessionReady(code: String) async -> Bool
}

struct CloudKitAccessCodeClient: AccessCodeCloudClient {
    private let container: CKContainer

    init(container: CKContainer = CKContainer(identifier: "iCloud.SysInspectDB")) {
        self.container = container
    }

    func accountAvailable() async -> Bool {
        do {
            return try await container.accountStatus() == .available
        } catch {
            return false
        }
    }

    func userRecordName() async -> String? {
        do {
            return try await container.userRecordID().recordName
        } catch {
            return nil
        }
    }

    func fetch(code: String) async -> AccessCodeRecordState {
        do {
            let record = try await container.publicCloudDatabase.record(for: CKRecord.ID(recordName: code))
            return state(from: record)
        } catch let error as CKError where error.code == .unknownItem {
            return .missing
        } catch {
            return .unreadable
        }
    }

    func claim(code: String, userRecordName: String) async -> Bool {
        let database = container.publicCloudDatabase
        let recordID = CKRecord.ID(recordName: code)
        do {
            let record = try await database.record(for: recordID)
            let status = record[AccessCodeCloudField.status] as? String
            if status == AccessCodeCloudField.claimed,
               record[AccessCodeCloudField.claimedUserRecordName] as? String == userRecordName {
                return true
            }
            guard status == AccessCodeCloudField.issued else { return false }
            record[AccessCodeCloudField.status] = AccessCodeCloudField.claimed as CKRecordValue
            record[AccessCodeCloudField.claimedUserRecordName] = userRecordName as CKRecordValue
            record[AccessCodeCloudField.claimedAt] = Date() as CKRecordValue
            record[AccessCodeCloudField.sessionReady] = NSNumber(value: false)
            _ = try await database.modifyRecords(saving: [record], deleting: [])
            return true
        } catch {
            let current = await fetch(code: code)
            if case .claimed(let owner, _) = current, owner == userRecordName {
                return true
            }
            return false
        }
    }

    func markSessionReady(code: String) async -> Bool {
        let database = container.publicCloudDatabase
        do {
            let record = try await database.record(for: CKRecord.ID(recordName: code))
            record[AccessCodeCloudField.sessionReady] = NSNumber(value: true)
            _ = try await database.modifyRecords(saving: [record], deleting: [])
            return true
        } catch {
            return false
        }
    }

    private func state(from record: CKRecord) -> AccessCodeRecordState {
        let ready = (record[AccessCodeCloudField.sessionReady] as? NSNumber)?.boolValue ?? false
        switch record[AccessCodeCloudField.status] as? String {
        case AccessCodeCloudField.issued:
            return .issued
        case AccessCodeCloudField.claimed:
            let owner = record[AccessCodeCloudField.claimedUserRecordName] as? String ?? ""
            return .claimed(userRecordName: owner, sessionReady: ready)
        case AccessCodeCloudField.retired:
            return .retired
        default:
            return .unreadable
        }
    }
}
