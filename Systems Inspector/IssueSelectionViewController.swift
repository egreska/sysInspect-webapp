//
//  IssueSelectionViewController.swift
//  Systems Inspector
//

import UIKit

protocol IssueSelectionDelegate: AnyObject {
    func didSelectIssues(_ selected: Set<Issue.Path>)
}

class IssueSelectionViewController: UIViewController {
    weak var delegate: IssueSelectionDelegate?
    var selected: Set<Issue.Path> = []

    private let tableView = UITableView()
    private let nodes = Issue.flattened()
    private var filtered: [Issue.Node] = []
    private let searchController = UISearchController(searchResultsController: nil)

    override func viewDidLoad() {
        super.viewDidLoad()
        filtered = nodes
        setupUI()
    }

    private func setupUI() {
        title = "Select Issue"
        view.backgroundColor = .systemBackground

        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelTapped))
        let doneSymbol = UIImage.SymbolConfiguration(hierarchicalColor: .systemGreen)
        let doneImage = UIImage(systemName: "checkmark", withConfiguration: doneSymbol)?
            .withRenderingMode(.alwaysOriginal)
        let doneItem = UIBarButtonItem(image: doneImage, style: .done, target: self, action: #selector(doneTapped))
        doneItem.tintColor = .systemGreen
        doneItem.accessibilityLabel = "Done"
        navigationItem.rightBarButtonItem = doneItem

        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search issues"
        searchController.searchBar.accessibilityLabel = "Search issues"
        searchController.searchBar.accessibilityHint = "Filter issues by name"
        navigationItem.searchController = searchController
        definesPresentationContext = true

        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }

    private func filterNodes(for query: String?) {
        guard let q = query?.trimmingCharacters(in: .whitespacesAndNewlines), !q.isEmpty else {
            filtered = nodes
            return
        }
        let lower = q.lowercased()
        filtered = nodes.filter { $0.path.name.lowercased().contains(lower) }
    }

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }

    @objc private func doneTapped() {
        delegate?.didSelectIssues(selected)
        dismiss(animated: true)
    }
}

extension IssueSelectionViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        filtered.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let node = filtered[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        let level = max(node.path.segments.count - 1, 0)
        let indentation = String(repeating: "    ", count: level)
        let isSelected = Issue.isDisplayedAsSelected(node.path, in: selected)
        cell.textLabel?.text = indentation + node.path.name
        cell.accessoryType = isSelected ? .checkmark : .none
        cell.accessibilityLabel = node.path.name
        cell.accessibilityValue = isSelected ? "Selected" : "Not selected"
        cell.accessibilityHint = "Double tap to select or deselect"
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let node = filtered[indexPath.row]
        selected = Issue.toggling(node.path, in: selected)
        tableView.reloadData()
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

extension IssueSelectionViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        filterNodes(for: searchController.searchBar.text)
        tableView.reloadData()
    }
}
