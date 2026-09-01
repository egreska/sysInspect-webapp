//
//  ReportPDFLayoutOptionsViewController.swift
//  Systems Inspector
//
//  Lets the user choose PDF table layout: include Secondary Location column and column size preset.
//

import UIKit

protocol ReportPDFLayoutOptionsDelegate: AnyObject {
    func reportPDFLayoutOptions(_ controller: ReportPDFLayoutOptionsViewController, didChoose options: PDFLayoutOptions)
}

final class ReportPDFLayoutOptionsViewController: UIViewController {
    weak var delegate: ReportPDFLayoutOptionsDelegate?
    
    private var includeSecondary = false
    private var preset: PDFLayoutOptions.ColumnPreset = .standard
    
    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private let secondarySwitch = UISwitch()
    private let secondaryLabel = UILabel()
    private let presetLabel = UILabel()
    private let presetSegmented = UISegmentedControl(items: PDFLayoutOptions.ColumnPreset.allCases.map(\.rawValue))
    private let generateButton = UIButton(type: .system)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "PDF Layout"
        view.backgroundColor = AppTheme.background
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelTapped))
        
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        secondaryLabel.text = "Always include Secondary Location (Bay/Level)"
        secondaryLabel.font = AppTheme.font(.body)
        secondaryLabel.numberOfLines = 0
        secondaryLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        secondarySwitch.isOn = includeSecondary
        secondarySwitch.setContentCompressionResistancePriority(.required, for: .horizontal)
        secondarySwitch.addTarget(self, action: #selector(secondaryChanged), for: .valueChanged)
        
        presetLabel.text = "Column density"
        presetLabel.font = AppTheme.font(.headline)
        presetSegmented.selectedSegmentIndex = 1
        presetSegmented.addTarget(self, action: #selector(presetChanged), for: .valueChanged)
        
        let hintLabel = UILabel()
        hintLabel.text = "Image, comments, and secondary location columns are added automatically when the report has that data. Density changes photo and label size."
        hintLabel.font = AppTheme.font(.footnote)
        hintLabel.textColor = AppTheme.textSecondary
        hintLabel.numberOfLines = 0
        
        generateButton.setTitle("Generate PDF", for: .normal)
        generateButton.backgroundColor = AppTheme.primary
        generateButton.setTitleColor(AppTheme.primaryContrast, for: .normal)
        generateButton.layer.cornerRadius = 8
        generateButton.addTarget(self, action: #selector(generateTapped), for: .touchUpInside)
        
        let secondaryRow = UIView()
        secondaryRow.translatesAutoresizingMaskIntoConstraints = false
        secondaryLabel.translatesAutoresizingMaskIntoConstraints = false
        secondarySwitch.translatesAutoresizingMaskIntoConstraints = false
        secondaryRow.addSubview(secondaryLabel)
        secondaryRow.addSubview(secondarySwitch)
        NSLayoutConstraint.activate([
            secondarySwitch.leadingAnchor.constraint(equalTo: secondaryRow.leadingAnchor),
            secondarySwitch.centerYAnchor.constraint(equalTo: secondaryRow.centerYAnchor),
            secondaryLabel.leadingAnchor.constraint(equalTo: secondarySwitch.trailingAnchor, constant: 12),
            secondaryLabel.centerYAnchor.constraint(equalTo: secondaryRow.centerYAnchor),
            secondaryLabel.trailingAnchor.constraint(lessThanOrEqualTo: secondaryRow.trailingAnchor),
            secondaryRow.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])
        
        presetLabel.translatesAutoresizingMaskIntoConstraints = false
        presetSegmented.translatesAutoresizingMaskIntoConstraints = false
        generateButton.translatesAutoresizingMaskIntoConstraints = false
        
        stack.addArrangedSubview(secondaryRow)
        stack.addArrangedSubview(hintLabel)
        stack.addArrangedSubview(presetLabel)
        stack.addArrangedSubview(presetSegmented)
        stack.addArrangedSubview(generateButton)
        
        view.addSubview(scrollView)
        scrollView.addSubview(stack)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -24),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
            stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -48),
            generateButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    @objc private func secondaryChanged() {
        includeSecondary = secondarySwitch.isOn
    }
    
    @objc private func presetChanged() {
        let index = presetSegmented.selectedSegmentIndex
        if index >= 0, index < PDFLayoutOptions.ColumnPreset.allCases.count {
            preset = PDFLayoutOptions.ColumnPreset.allCases[index]
        }
    }
    
    @objc private func generateTapped() {
        let options = PDFLayoutOptions(includeSecondaryLocation: includeSecondary, preset: preset)
        delegate?.reportPDFLayoutOptions(self, didChoose: options)
        dismiss(animated: true)
    }
    
    @objc private func cancelTapped() {
        dismiss(animated: true)
    }
}
