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
    func claim(code: String, userRecordName: String) async -> ClaimResult
    func markSessionReady(code: String) async -> Bool
    func clearSessionReady(code: String) async -> Bool
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

    func claim(code: String, userRecordName: String) async -> ClaimResult {
        let database = container.publicCloudDatabase
        let recordID = CKRecord.ID(recordName: code)
        do {
            let record = try await database.record(for: recordID)
            let current = state(from: record)
            if case .claimed(let owner, _) = current, owner == userRecordName {
                return .accepted
            }
            guard case .issued = current else { return .failed(current) }
            record[AccessCodeCloudField.status] = AccessCodeCloudField.claimed as CKRecordValue
            record[AccessCodeCloudField.claimedUserRecordName] = userRecordName as CKRecordValue
            record[AccessCodeCloudField.claimedAt] = Date() as CKRecordValue
            record[AccessCodeCloudField.sessionReady] = sessionReadyValue(false)
            _ = try await database.modifyRecords(saving: [record], deleting: [])
            return .accepted
        } catch {
            let current = await fetch(code: code)
            if case .claimed(let owner, _) = current, owner == userRecordName {
                return .accepted
            }
            if case .issued = current {
                return .failed(.unreadable)
            }
            return .failed(current)
        }
    }

    func markSessionReady(code: String) async -> Bool {
        await setSessionReady(code: code, ready: true)
    }

    func clearSessionReady(code: String) async -> Bool {
        await setSessionReady(code: code, ready: false)
    }

    private func setSessionReady(code: String, ready: Bool) async -> Bool {
        let database = container.publicCloudDatabase
        do {
            let record = try await database.record(for: CKRecord.ID(recordName: code))
            record[AccessCodeCloudField.sessionReady] = sessionReadyValue(ready)
            _ = try await database.modifyRecords(saving: [record], deleting: [])
            return true
        } catch {
            return false
        }
    }

    private func sessionReadyValue(_ ready: Bool) -> NSNumber {
        NSNumber(value: ready ? Int64(1) : Int64(0))
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
