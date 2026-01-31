//
//  DamageComponentSelectionViewController.swift
//  Systems Inspector
//
//  Created by Eric Greska on 5/25/25.
//

import Foundation
import UIKit

protocol DamageComponentSelectionDelegate: AnyObject {
    func didSelectDamageComponents(_ components: [DamageComponent])
}

class DamageComponentSelectionViewController: UIViewController {
    weak var delegate: DamageComponentSelectionDelegate?
    var damageComponents: [DamageComponent] = []
    var selectedComponents: [DamageComponent] = []
    
    private let tableView = UITableView()
    private var flattenedComponents: [DamageComponent] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        flattenedComponents = flattenComponentHierarchy(damageComponents)
    }
    
    private func setupUI() {
        title = "Select Issue"  // CHANGED from "Select Damage Components"
        view.backgroundColor = .systemBackground
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelTapped))
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneTapped))
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    @objc private func cancelTapped() {
        dismiss(animated: true)
    }
    
    @objc private func doneTapped() {
        delegate?.didSelectDamageComponents(getSelectedComponents())
        dismiss(animated: true)
    }
    
    private func flattenComponentHierarchy(_ components: [DamageComponent]) -> [DamageComponent] {
        var result: [DamageComponent] = []
        for component in components {
            result.append(component)
            result.append(contentsOf: flattenComponentHierarchy(component.children))
        }
        return result
    }
    
    private func getComponentLevel(_ component: DamageComponent) -> Int {
        var level = 0
        var currentParent = component.parent
        while currentParent != nil {
            level += 1
            currentParent = currentParent?.parent
        }
        return level
    }
    
    private func getSelectedComponents() -> [DamageComponent] {
        return flattenedComponents.filter { $0.isSelected }
    }
}

extension DamageComponentSelectionViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return flattenedComponents.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let component = flattenedComponents[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        
        let level = getComponentLevel(component)
        let indentation = String(repeating: "    ", count: level)
        cell.textLabel?.text = indentation + component.name
        cell.accessoryType = component.isSelected ? .checkmark : .none
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let component = flattenedComponents[indexPath.row]
        component.isSelected.toggle()
        
        if component.isSelected {
            component.selectParent()
        } else {
            component.deselectChildren()
        }
        
        tableView.reloadData()
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
