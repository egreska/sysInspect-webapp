//
//  Importance.swift
//  Systems Inspector
//

import Foundation

public enum Importance: Equatable, Comparable {
    case needsImmediateAttention
    case monitor

    public init(stored raw: String?) {
        switch raw {
        case "Needs immediate attention", "Critical":
            self = .needsImmediateAttention
        default:
            self = .monitor
        }
    }

    public var isImmediate: Bool {
        self == .needsImmediateAttention
    }

    public var phrase: String {
        switch self {
        case .needsImmediateAttention:
            return "Needs immediate attention"
        case .monitor:
            return "Monitor"
        }
    }

    public var toggled: Importance {
        switch self {
        case .needsImmediateAttention:
            return .monitor
        case .monitor:
            return .needsImmediateAttention
        }
    }

    public struct Counts: Equatable {
        public var immediate: Int
        public var monitor: Int
    }

    public static func counts(in values: [Importance]) -> Counts {
        Counts(
            immediate: values.filter(\.isImmediate).count,
            monitor: values.filter { !$0.isImmediate }.count
        )
    }
}
