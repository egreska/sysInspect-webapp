//
//  HapticManager.swift
//  Systems Inspector
//
//  Lightweight haptic feedback for success and error flows.
//

import UIKit

enum HapticManager {
    private static let successGenerator = UINotificationFeedbackGenerator()
    private static let errorGenerator = UINotificationFeedbackGenerator()
    private static let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    
    static func prepare() {
        successGenerator.prepare()
        errorGenerator.prepare()
        lightGenerator.prepare()
    }
    
    static func success() {
        successGenerator.notificationOccurred(.success)
    }
    
    static func error() {
        errorGenerator.notificationOccurred(.error)
    }
    
    static func lightImpact() {
        lightGenerator.impactOccurred()
    }
}
