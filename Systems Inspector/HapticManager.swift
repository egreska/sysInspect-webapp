//
//  HapticManager.swift
//  Systems Inspector
//
//  Lightweight haptic feedback for success and error flows.
//

import UIKit

enum HapticManager {
    private static let notificationGenerator = UINotificationFeedbackGenerator()
    private static let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    
    static func prepare() {
        notificationGenerator.prepare()
        lightGenerator.prepare()
    }
    
    static func success() {
        notificationGenerator.notificationOccurred(.success)
    }
    
    static func error() {
        notificationGenerator.notificationOccurred(.error)
    }
    
    static func lightImpact() {
        lightGenerator.impactOccurred()
    }
}
