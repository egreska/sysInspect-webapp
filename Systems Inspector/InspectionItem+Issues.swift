//
//  InspectionItem+Issues.swift
//  Systems Inspector
//

import CoreData

extension InspectionItem {
    func recordedIssues() -> Set<Issue.Path> {
        Issue.selectedPaths(from: issueFlagMap())
    }

    func replaceIssues(_ issues: Set<Issue.Path>) {
        applyIssueFlags(Issue.flags(from: issues))
    }

    private func issueFlagMap() -> [Issue.Flag: Bool] {
        Dictionary(uniqueKeysWithValues: Issue.Flag.allCases.map { flag in
            (flag, bool(forIssueFlag: flag))
        })
    }

    private func applyIssueFlags(_ flags: [Issue.Flag: Bool]) {
        for flag in Issue.Flag.allCases {
            setValue(flags[flag, default: false], forKey: flag.rawValue)
        }
    }

    private func bool(forIssueFlag flag: Issue.Flag) -> Bool {
        switch value(forKey: flag.rawValue) {
        case let number as NSNumber:
            return number.boolValue
        case let value as Bool:
            return value
        default:
            return false
        }
    }
}
