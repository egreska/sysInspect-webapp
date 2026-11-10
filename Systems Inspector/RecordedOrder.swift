//
//  RecordedOrder.swift
//  Systems Inspector
//

import Foundation

enum RecordedOrder {
    static func sorted<T>(_ items: [T], sequence: (T) -> Int32) -> [T] {
        items.enumerated().sorted { lhs, rhs in
            let left = sequence(lhs.element)
            let right = sequence(rhs.element)
            if left != right { return left < right }
            return lhs.offset < rhs.offset
        }.map(\.element)
    }
}
