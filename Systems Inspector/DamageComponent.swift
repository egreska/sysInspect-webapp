//
//  DamageComponent.swift
//  Systems Inspector
//
//  Created by Eric Greska on 5/22/25.
//
import Foundation

// MARK: - Simple DamageComponent for UI (Not Core Data)
class DamageComponent {
    let id = UUID()
    let name: String
    var isSelected: Bool = false
    weak var parent: DamageComponent?
    var children: [DamageComponent] = []

    init(name: String, children: [DamageComponent] = []) {
        self.name = name
        self.children = children
        // Set parent relationships
        for child in children {
            child.parent = self
        }
    }

    func selectParent() {
        isSelected = true
        parent?.selectParent()
    }

    func deselectChildren() {
        isSelected = false
        children.forEach { $0.deselectChildren() }
    }

    func getSelectedComponents() -> [DamageComponent] {
        var selected = [DamageComponent]()
        if isSelected {
            selected.append(self)
        }
        children.forEach { selected.append(contentsOf: $0.getSelectedComponents()) }
        return selected
    }
}
