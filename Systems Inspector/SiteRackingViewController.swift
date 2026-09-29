//
//  SiteRackingViewController.swift
//  Systems Inspector
//

import AVFoundation
import CoreData
import PhotosUI
import QuickLook
import UIKit
import UniformTypeIdentifiers

final class SiteRackingViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIDocumentPickerDelegate, PHPickerViewControllerDelegate, QLPreviewControllerDataSource {
    private var racking: SiteRacking
    private var documents: [SiteDocumentFile]
    private let context: NSManagedObjectContext
    private let onDone: (SiteRacking, [SiteDocumentFile]) -> Void
    private var previewURL: URL?

    private enum CardID: String {
        case siteInformation
        case loadInformation
        case documents
        case uprights
        case beams
        case decks
        case crossBars
        case safetyClips
        case anchors
        case rowSpacers
    }

    private let scrollView = UIScrollView()
    private let stackView = UIStackView()
    private var expandedCards: Set<CardID> = [.siteInformation]

    init(
        siteRacking: SiteRacking,
        siteDocuments: [SiteDocumentFile],
        context: NSManagedObjectContext = CoreDataManager.shared.context,
        onDone: @escaping (SiteRacking, [SiteDocumentFile]) -> Void
    ) {
        self.racking = siteRacking
        self.documents = siteDocuments
        self.context = context
        self.onDone = onDone
        super.init(nibName: nil, bundle: nil)
        ensurePlaceholderRows()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Site Racking"
        view.backgroundColor = .systemGroupedBackground
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelTapped)
        )
        let doneSymbol = UIImage.SymbolConfiguration(hierarchicalColor: .systemGreen)
        let doneImage = UIImage(systemName: "checkmark", withConfiguration: doneSymbol)?
            .withRenderingMode(.alwaysOriginal)
        let doneItem = UIBarButtonItem(image: doneImage, style: .done, target: self, action: #selector(doneTapped))
        doneItem.tintColor = .systemGreen
        doneItem.accessibilityLabel = "Done"
        navigationItem.rightBarButtonItem = doneItem
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = 12
        stackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(stackView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -24),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32)
        ])
        rebuild()
    }

    private func ensurePlaceholderRows() {
        racking.uprights.seedBlankIfEmpty()
        racking.beams.seedBlankIfEmpty()
        racking.decks.seedBlankIfEmpty()
        racking.crossBars.seedBlankIfEmpty()
        racking.anchors.seedBlankIfEmpty()
        racking.rowSpacers.seedBlankIfEmpty()
    }

    private func rebuild() {
        let offset = scrollView.contentOffset
        stackView.arrangedSubviews.forEach {
            stackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        stackView.addArrangedSubview(collapsibleCard(
            id: .siteInformation,
            title: "Site Information",
            symbolName: "building.2",
            summary: racking.siteInformationSummary,
            body: siteInformationCard()
        ))
        stackView.addArrangedSubview(collapsibleCard(
            id: .loadInformation,
            title: "Load Information",
            symbolName: "shippingbox",
            summary: racking.loadInformationSummary,
            body: loadInformationCard()
        ))
        stackView.addArrangedSubview(collapsibleCard(
            id: .documents,
            title: "Site documents",
            symbolName: "doc",
            summary: SiteRacking.documentsSummary(count: documents.count),
            body: documentsView()
        ))
        stackView.addArrangedSubview(collapsibleCard(
            id: .uprights,
            title: "Upright Frames",
            symbolName: "rectangle.split.3x1",
            summary: racking.uprightsSummary,
            body: manufacturerBody(
                toolbar: modeToolbar(
                    mode: racking.uprights.mode,
                    allowsStandardized: racking.uprights.allowsStandardized,
                    addEnabled: racking.uprights.mode == .mixed,
                    onMode: { [weak self] mixed in self?.setUprightsMixed(mixed) },
                    onAdd: { [weak self] in
                        self?.racking.uprights.appendBlank()
                        self?.rebuild()
                    }
                ),
                rows: racking.uprights.rows.indices.map { uprightCard(index: $0) }
            )
        ))
        stackView.addArrangedSubview(collapsibleCard(
            id: .beams,
            title: "Beams",
            symbolName: "rectangle.portrait",
            summary: racking.beamsSummary,
            body: manufacturerBody(
                toolbar: modeToolbar(
                    mode: racking.beams.mode,
                    allowsStandardized: racking.beams.allowsStandardized,
                    addEnabled: racking.beams.mode == .mixed,
                    onMode: { [weak self] mixed in self?.setBeamsMixed(mixed) },
                    onAdd: { [weak self] in
                        self?.racking.beams.appendBlank()
                        self?.rebuild()
                    }
                ),
                rows: racking.beams.rows.indices.map { beamCard(index: $0) }
            )
        ))
        stackView.addArrangedSubview(collapsibleCard(
            id: .decks,
            title: "Wire Decks",
            symbolName: "square.grid.3x3",
            summary: racking.decksSummary,
            body: manufacturerBody(
                toolbar: modeToolbar(
                    mode: racking.decks.mode,
                    allowsStandardized: racking.decks.allowsStandardized,
                    addEnabled: racking.decks.mode == .mixed,
                    onMode: { [weak self] mixed in self?.setDecksMixed(mixed) },
                    onAdd: { [weak self] in
                        self?.racking.decks.appendBlank()
                        self?.rebuild()
                    }
                ),
                rows: racking.decks.rows.indices.map { deckCard(index: $0) }
            )
        ))
        stackView.addArrangedSubview(collapsibleCard(
            id: .crossBars,
            title: "Cross Bars",
            symbolName: "minus",
            summary: racking.crossBarsSummary,
            body: manufacturerBody(
                toolbar: modeToolbar(
                    mode: racking.crossBars.mode,
                    allowsStandardized: racking.crossBars.allowsStandardized,
                    addEnabled: racking.crossBars.mode == .mixed,
                    onMode: { [weak self] mixed in self?.setCrossBarsMixed(mixed) },
                    onAdd: { [weak self] in
                        self?.racking.crossBars.appendBlank()
                        self?.rebuild()
                    }
                ),
                rows: racking.crossBars.rows.indices.map { crossBarCard(index: $0) }
            )
        ))
        stackView.addArrangedSubview(collapsibleCard(
            id: .safetyClips,
            title: "Safety Clips",
            symbolName: "paperclip",
            summary: racking.safetyClipsSummary,
            body: safetyClipsCard()
        ))
        stackView.addArrangedSubview(collapsibleCard(
            id: .anchors,
            title: "Anchors",
            symbolName: "anchor",
            summary: racking.anchorsSummary,
            body: manufacturerBody(
                toolbar: modeToolbar(
                    mode: racking.anchors.mode,
                    allowsStandardized: racking.anchors.allowsStandardized,
                    addEnabled: racking.anchors.mode == .mixed,
                    onMode: { [weak self] mixed in self?.setAnchorsMixed(mixed) },
                    onAdd: { [weak self] in
                        self?.racking.anchors.appendBlank()
                        self?.rebuild()
                    }
                ),
                rows: racking.anchors.rows.indices.map { anchorCard(index: $0) }
            )
        ))
        stackView.addArrangedSubview(collapsibleCard(
            id: .rowSpacers,
            title: "Row Spacers",
            symbolName: "arrow.left.and.right",
            summary: racking.rowSpacersSummary,
            body: manufacturerBody(
                toolbar: modeToolbar(
                    mode: racking.rowSpacers.mode,
                    allowsStandardized: racking.rowSpacers.allowsStandardized,
                    addEnabled: racking.rowSpacers.mode == .mixed,
                    onMode: { [weak self] mixed in self?.setRowSpacersMixed(mixed) },
                    onAdd: { [weak self] in
                        self?.racking.rowSpacers.appendBlank()
                        self?.rebuild()
                    }
                ),
                rows: racking.rowSpacers.rows.indices.map { rowSpacerCard(index: $0) }
            )
        ))
        view.layoutIfNeeded()
        scrollView.setContentOffset(offset, animated: false)
    }

    private func setUprightsMixed(_ mixed: Bool) {
        applyMode(mixed, to: &racking.uprights)
        rebuild()
    }

    private func setBeamsMixed(_ mixed: Bool) {
        applyMode(mixed, to: &racking.beams)
        rebuild()
    }

    private func setDecksMixed(_ mixed: Bool) {
        applyMode(mixed, to: &racking.decks)
        rebuild()
    }

    private func setCrossBarsMixed(_ mixed: Bool) {
        applyMode(mixed, to: &racking.crossBars)
        rebuild()
    }

    private func setAnchorsMixed(_ mixed: Bool) {
        applyMode(mixed, to: &racking.anchors)
        rebuild()
    }

    private func setRowSpacersMixed(_ mixed: Bool) {
        applyMode(mixed, to: &racking.rowSpacers)
        rebuild()
    }

    private func applyMode<Row>(_ mixed: Bool, to section: inout SiteRackingSection<Row>) {
        section.setMode(mixed ? .mixed : .standardized)
        section.seedBlankIfEmpty()
    }

    private func toggleCard(_ id: CardID) {
        if expandedCards.contains(id) {
            expandedCards.remove(id)
        } else {
            expandedCards.insert(id)
        }
        rebuild()
    }

    private func collapsibleCard(
        id: CardID,
        title: String,
        symbolName: String,
        summary: String,
        body: @autoclosure () -> UIView
    ) -> UIView {
        let expanded = expandedCards.contains(id)
        let card = UIView()
        card.backgroundColor = AppTheme.surface
        card.layer.cornerRadius = 12
        card.clipsToBounds = true
        let column = UIStackView()
        column.axis = .vertical
        column.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(column)
        NSLayoutConstraint.activate([
            column.topAnchor.constraint(equalTo: card.topAnchor),
            column.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            column.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            column.bottomAnchor.constraint(equalTo: card.bottomAnchor)
        ])
        column.addArrangedSubview(
            cardHeader(id: id, title: title, symbolName: symbolName, summary: summary, expanded: expanded)
        )
        if expanded {
            column.addArrangedSubview(separatorLine())
            let inset = UIStackView()
            inset.axis = .vertical
            inset.isLayoutMarginsRelativeArrangement = true
            inset.layoutMargins = UIEdgeInsets(top: 12, left: 16, bottom: 16, right: 16)
            inset.addArrangedSubview(body())
            column.addArrangedSubview(inset)
        }
        return card
    }

    private func cardHeader(
        id: CardID,
        title: String,
        symbolName: String,
        summary: String,
        expanded: Bool
    ) -> UIView {
        let button = UIButton(type: .custom)
        button.addAction(UIAction { [weak self] _ in self?.toggleCard(id) }, for: .touchUpInside)
        button.accessibilityLabel = title
        button.accessibilityValue = expanded ? "Expanded, \(summary)" : summary
        button.accessibilityHint = expanded ? "Collapses this section" : "Expands this section"
        button.accessibilityTraits.insert(.header)
        let icon = UIImageView(image: UIImage(systemName: symbolName))
        icon.tintColor = AppTheme.secondary
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 22).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 22).isActive = true
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = AppTheme.fontBold(.body)
        titleLabel.textColor = AppTheme.textPrimary
        titleLabel.lineBreakMode = .byTruncatingTail
        let summaryLabel = UILabel()
        summaryLabel.text = summary
        summaryLabel.font = AppTheme.font(.footnote)
        summaryLabel.textColor = AppTheme.textSecondary
        summaryLabel.isHidden = expanded
        summaryLabel.lineBreakMode = .byTruncatingTail
        let textStack = UIStackView(arrangedSubviews: [titleLabel, summaryLabel])
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let chevron = UIImageView(image: UIImage(systemName: expanded ? "chevron.down" : "chevron.right"))
        chevron.tintColor = AppTheme.textTertiary
        chevron.contentMode = .scaleAspectFit
        chevron.translatesAutoresizingMaskIntoConstraints = false
        chevron.widthAnchor.constraint(equalToConstant: 14).isActive = true
        chevron.heightAnchor.constraint(equalToConstant: 16).isActive = true
        let row = UIStackView(arrangedSubviews: [icon, textStack, chevron])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 12
        row.isLayoutMarginsRelativeArrangement = true
        row.layoutMargins = UIEdgeInsets(top: 14, left: 16, bottom: 14, right: 16)
        row.isUserInteractionEnabled = false
        row.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: button.topAnchor),
            row.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            row.bottomAnchor.constraint(equalTo: button.bottomAnchor),
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])
        return button
    }

    private func manufacturerBody(toolbar: UIView, rows: [UIView]) -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.addArrangedSubview(toolbar)
        for (index, row) in rows.enumerated() {
            if index > 0 {
                stack.addArrangedSubview(separatorLine())
            }
            stack.addArrangedSubview(row)
        }
        return stack
    }

    private func separatorLine() -> UIView {
        let line = UIView()
        line.backgroundColor = AppTheme.separator
        line.translatesAutoresizingMaskIntoConstraints = false
        line.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return line
    }

    private func modeToolbar(
        mode: SiteRackingMode,
        allowsStandardized: Bool,
        addEnabled: Bool,
        onMode: @escaping (Bool) -> Void,
        onAdd: @escaping () -> Void
    ) -> UIView {
        let header = UIStackView()
        header.axis = .horizontal
        header.spacing = 8
        header.alignment = .center
        let control = UISegmentedControl(items: ["Standardized", "Mixed"])
        control.selectedSegmentIndex = mode == .mixed ? 1 : 0
        control.setEnabled(allowsStandardized, forSegmentAt: 0)
        control.addAction(UIAction { _ in
            onMode(control.selectedSegmentIndex == 1)
        }, for: .valueChanged)
        header.addArrangedSubview(control)
        if addEnabled {
            let add = UIButton(type: .system)
            add.setTitle("Add", for: .normal)
            add.addAction(UIAction { _ in onAdd() }, for: .touchUpInside)
            header.addArrangedSubview(add)
        }
        return header
    }

    private func documentsView() -> UIView {
        let wrap = UIStackView()
        wrap.axis = .vertical
        wrap.spacing = 8
        if documents.isEmpty {
            let empty = UILabel()
            empty.text = "Add photos or PDFs of the installed system."
            empty.font = AppTheme.font(.footnote)
            empty.textColor = AppTheme.textSecondary
            empty.numberOfLines = 0
            wrap.addArrangedSubview(empty)
        }
        let tiles = UIStackView()
        tiles.axis = .horizontal
        tiles.spacing = 8
        tiles.alignment = .center
        for (index, file) in documents.enumerated() {
            tiles.addArrangedSubview(documentTile(file: file, index: index))
        }
        let add = UIButton(type: .system)
        add.setTitle("Add", for: .normal)
        add.isEnabled = documents.count < Customer.maxSiteDocumentCount
        add.addAction(UIAction { [weak self] _ in self?.presentAddDocument() }, for: .touchUpInside)
        tiles.addArrangedSubview(add)
        wrap.addArrangedSubview(tiles)
        return wrap
    }

    private func documentTile(file: SiteDocumentFile, index: Int) -> UIView {
        let column = UIStackView()
        column.axis = .vertical
        column.spacing = 4
        column.alignment = .center
        let button = UIButton(type: .system)
        if file.contentType == "public.pdf" {
            button.setTitle("PDF", for: .normal)
        } else {
            button.setTitle("Photo", for: .normal)
        }
        button.addAction(UIAction { [weak self] _ in self?.previewDocument(at: index) }, for: .touchUpInside)
        let name = UILabel()
        name.text = file.filename
        name.font = AppTheme.font(.caption)
        name.textColor = AppTheme.textSecondary
        name.lineBreakMode = .byTruncatingMiddle
        let remove = UIButton(type: .system)
        remove.setTitle("Remove", for: .normal)
        remove.tintColor = AppTheme.destructive
        remove.addAction(UIAction { [weak self] _ in
            self?.documents.remove(at: index)
            self?.rebuild()
        }, for: .touchUpInside)
        column.addArrangedSubview(button)
        column.addArrangedSubview(name)
        column.addArrangedSubview(remove)
        return column
    }

    private func siteInformationCard() -> UIView {
        let card = UIStackView()
        card.axis = .vertical
        card.spacing = 8
        let fields: [(String, String?, (String) -> Void)] = [
            ("Number of Bays", racking.siteInformation.numberOfBays, { [weak self] text in
                self?.racking.siteInformation.numberOfBays = Self.optionalText(text)
            }),
            ("Number of Beam Levels", racking.siteInformation.numberOfBeamLevels, { [weak self] text in
                self?.racking.siteInformation.numberOfBeamLevels = Self.optionalText(text)
            }),
            ("Beam Spacing", racking.siteInformation.beamSpacing, { [weak self] text in
                self?.racking.siteInformation.beamSpacing = Self.optionalText(text)
            })
        ]
        for field in fields {
            card.addArrangedSubview(textField(placeholder: field.0, text: field.1, onChange: field.2))
        }
        return card
    }

    private func loadInformationCard() -> UIView {
        let card = UIStackView()
        card.axis = .vertical
        card.spacing = 8
        let fields: [(String, String?, (String) -> Void)] = [
            ("Maximum Weight", racking.loadInformation.maximumWeight, { [weak self] text in
                self?.racking.loadInformation.maximumWeight = Self.optionalText(text)
            }),
            ("Pallet Dimensions", racking.loadInformation.palletDimensions, { [weak self] text in
                self?.racking.loadInformation.palletDimensions = Self.optionalText(text)
            }),
            ("Load Dimensions", racking.loadInformation.loadDimensions, { [weak self] text in
                self?.racking.loadInformation.loadDimensions = Self.optionalText(text)
            }),
            ("What is being stored", racking.loadInformation.storedContents, { [weak self] text in
                self?.racking.loadInformation.storedContents = Self.optionalText(text)
            })
        ]
        for field in fields {
            card.addArrangedSubview(textField(placeholder: field.0, text: field.1, onChange: field.2))
        }
        return card
    }

    private func safetyClipsCard() -> UIView {
        let card = UIStackView()
        card.axis = .vertical
        card.spacing = 8
        let header = UIStackView()
        header.axis = .horizontal
        header.spacing = 8
        header.alignment = .center
        let presentLabel = UILabel()
        presentLabel.text = "Present"
        presentLabel.font = AppTheme.font(.body)
        presentLabel.textColor = AppTheme.textPrimary
        let control = UISegmentedControl(items: ["No", "Yes"])
        control.selectedSegmentIndex = racking.safetyClips.present ? 1 : 0
        control.accessibilityLabel = "Present"
        control.addAction(UIAction { [weak self] _ in
            self?.racking.safetyClips.present = control.selectedSegmentIndex == 1
            self?.rebuild()
        }, for: .valueChanged)
        header.addArrangedSubview(presentLabel)
        header.addArrangedSubview(control)
        card.addArrangedSubview(header)
        let needed = textField(
            placeholder: "# Needed",
            text: racking.safetyClips.neededCount,
            onChange: { [weak self] text in
                self?.racking.safetyClips.neededCount = Self.optionalText(text)
            }
        )
        needed.isEnabled = racking.safetyClips.present
        needed.alpha = racking.safetyClips.present ? 1 : 0.4
        needed.accessibilityLabel = "Number needed"
        card.addArrangedSubview(needed)
        return card
    }

    private func textField(placeholder: String, text: String?, onChange: @escaping (String) -> Void) -> UITextField {
        let textField = UITextField()
        textField.placeholder = placeholder
        textField.text = text
        textField.borderStyle = .roundedRect
        textField.heightAnchor.constraint(equalToConstant: 44).isActive = true
        textField.addAction(UIAction { _ in
            onChange(textField.text ?? "")
        }, for: .editingChanged)
        return textField
    }

    private func uprightCard(index: Int) -> UIView {
        let spec = racking.uprights[index]
        return specCard(
            manufacturer: spec.manufacturer,
            fields: [
                ("Type", spec.type),
                ("Height", spec.height),
                ("Depth", spec.depth),
                ("Capacity", spec.capacity)
            ],
            footerControl: constructionToggle(spec.construction) { [weak self] construction in
                self?.racking.uprights[index].construction = construction
            },
            onManufacturer: { [weak self] name in
                self?.racking.uprights[index].manufacturer = name
                self?.rebuild()
            },
            onField: { [weak self] fieldIndex, text in
                switch fieldIndex {
                case 0: self?.racking.uprights[index].type = Self.optionalText(text)
                case 1: self?.racking.uprights[index].height = Self.optionalText(text)
                case 2: self?.racking.uprights[index].depth = Self.optionalText(text)
                default: self?.racking.uprights[index].capacity = Self.optionalText(text)
                }
            }
        )
    }

    private func beamCard(index: Int) -> UIView {
        let spec = racking.beams[index]
        return specCard(
            manufacturer: spec.manufacturer,
            fields: [
                ("Type", spec.type),
                ("Length", spec.length),
                ("Face", spec.face),
                ("Step Dimensions", spec.stepDimensions),
                ("Capacity", spec.capacity)
            ],
            onManufacturer: { [weak self] name in
                self?.racking.beams[index].manufacturer = name
                self?.rebuild()
            },
            onField: { [weak self] fieldIndex, text in
                switch fieldIndex {
                case 0: self?.racking.beams[index].type = Self.optionalText(text)
                case 1: self?.racking.beams[index].length = Self.optionalText(text)
                case 2: self?.racking.beams[index].face = Self.optionalText(text)
                case 3: self?.racking.beams[index].stepDimensions = Self.optionalText(text)
                default: self?.racking.beams[index].capacity = Self.optionalText(text)
                }
            }
        )
    }

    private func deckCard(index: Int) -> UIView {
        let spec = racking.decks[index]
        let card = UIStackView()
        card.axis = .vertical
        card.spacing = 8
        card.addArrangedSubview(catalogPullDown(
            kind: .wireDeckManufacturer,
            current: spec.manufacturer,
            placeholder: "Manufacturer"
        ) { [weak self] name in
            self?.racking.decks[index].manufacturer = name
            self?.rebuild()
        })
        card.addArrangedSubview(textField(placeholder: "Capacity", text: spec.capacity) { [weak self] text in
            self?.racking.decks[index].capacity = Self.optionalText(text)
        })
        card.addArrangedSubview(catalogPullDown(
            kind: .deckType,
            current: spec.type,
            placeholder: "Type"
        ) { [weak self] type in
            self?.racking.decks[index].type = type
            self?.rebuild()
        })
        card.addArrangedSubview(yesNoToggle(title: "UDL", isOn: spec.udl, accessibilityLabel: "UDL") { [weak self] isOn in
            self?.racking.decks[index].udl = isOn
            self?.rebuild()
        })
        card.addArrangedSubview(textField(placeholder: "Number of Decks", text: spec.numberOfDecks) { [weak self] text in
            self?.racking.decks[index].numberOfDecks = Self.optionalText(text)
        })
        return card
    }

    private func crossBarCard(index: Int) -> UIView {
        let spec = racking.crossBars[index]
        return specCard(
            manufacturer: spec.manufacturer,
            fields: [("Size", spec.size)],
            onManufacturer: { [weak self] name in
                self?.racking.crossBars[index].manufacturer = name
                self?.rebuild()
            },
            onField: { [weak self] _, text in
                self?.racking.crossBars[index].size = Self.optionalText(text)
            }
        )
    }

    private func anchorCard(index: Int) -> UIView {
        let spec = racking.anchors[index]
        return specCard(
            manufacturer: spec.manufacturer,
            fields: [("Size", spec.size)],
            onManufacturer: { [weak self] name in
                self?.racking.anchors[index].manufacturer = name
                self?.rebuild()
            },
            onField: { [weak self] _, text in
                self?.racking.anchors[index].size = Self.optionalText(text)
            }
        )
    }

    private func rowSpacerCard(index: Int) -> UIView {
        let spec = racking.rowSpacers[index]
        return specCard(
            manufacturer: spec.manufacturer,
            fields: [
                ("Length", spec.length),
                ("Width", spec.width)
            ],
            onManufacturer: { [weak self] name in
                self?.racking.rowSpacers[index].manufacturer = name
                self?.rebuild()
            },
            onField: { [weak self] fieldIndex, text in
                if fieldIndex == 0 {
                    self?.racking.rowSpacers[index].length = Self.optionalText(text)
                } else {
                    self?.racking.rowSpacers[index].width = Self.optionalText(text)
                }
            }
        )
    }

    private func yesNoToggle(title: String, isOn: Bool, accessibilityLabel: String, onChange: @escaping (Bool) -> Void) -> UIView {
        let header = UIStackView()
        header.axis = .horizontal
        header.spacing = 8
        header.alignment = .center
        let label = UILabel()
        label.text = title
        label.font = AppTheme.font(.body)
        label.textColor = AppTheme.textPrimary
        let control = UISegmentedControl(items: ["No", "Yes"])
        control.selectedSegmentIndex = isOn ? 1 : 0
        control.accessibilityLabel = accessibilityLabel
        control.addAction(UIAction { _ in
            onChange(control.selectedSegmentIndex == 1)
        }, for: .valueChanged)
        header.addArrangedSubview(label)
        header.addArrangedSubview(control)
        return header
    }

    private func constructionToggle(_ construction: RackingConstruction, onChange: @escaping (RackingConstruction) -> Void) -> UIView {
        let control = UISegmentedControl(items: ["Structural", "Roll Formed"])
        control.selectedSegmentIndex = construction == .rollFormed ? 1 : 0
        control.accessibilityLabel = "Construction"
        control.heightAnchor.constraint(equalToConstant: 44).isActive = true
        control.addAction(UIAction { _ in
            onChange(control.selectedSegmentIndex == 1 ? .rollFormed : .structural)
        }, for: .valueChanged)
        return control
    }

    private func specCard(
        manufacturer: String,
        fields: [(String, String?)],
        extraControl: UIView? = nil,
        footerControl: UIView? = nil,
        onManufacturer: @escaping (String) -> Void,
        onField: @escaping (Int, String) -> Void
    ) -> UIView {
        let card = UIStackView()
        card.axis = .vertical
        card.spacing = 8
        card.addArrangedSubview(catalogPullDown(
            kind: .manufacturer,
            current: manufacturer,
            placeholder: "Manufacturer",
            picked: onManufacturer
        ))
        if let extraControl {
            card.addArrangedSubview(extraControl)
        }
        for (fieldIndex, field) in fields.enumerated() {
            let textField = UITextField()
            textField.placeholder = field.0
            textField.text = field.1
            textField.borderStyle = .roundedRect
            textField.heightAnchor.constraint(equalToConstant: 44).isActive = true
            textField.addAction(UIAction { _ in
                onField(fieldIndex, textField.text ?? "")
            }, for: .editingChanged)
            card.addArrangedSubview(textField)
        }
        if let footerControl {
            card.addArrangedSubview(footerControl)
        }
        return card
    }

    private static func optionalText(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func userId() -> UUID? {
        UserManager.shared.sessionUserId
    }

    private func catalogPullDown(
        kind: CatalogKind,
        current: String,
        placeholder: String,
        picked: @escaping (String) -> Void
    ) -> UIButton {
        let title = current.isEmpty ? placeholder : current
        var config = UIButton.Configuration.gray()
        config.cornerStyle = .medium
        config.title = title
        config.baseForegroundColor = current.isEmpty ? AppTheme.placeholder : AppTheme.textPrimary
        config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12)
        config.titleAlignment = .leading
        config.titleLineBreakMode = .byTruncatingTail
        if #available(iOS 16.0, *) {
            config.indicator = .popup
        } else {
            config.image = UIImage(systemName: "chevron.up.chevron.down")
            config.imagePlacement = .trailing
            config.imagePadding = 8
            config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 10, weight: .semibold)
        }
        let button = UIButton(configuration: config)
        button.contentHorizontalAlignment = .leading
        button.heightAnchor.constraint(equalToConstant: 44).isActive = true
        button.accessibilityLabel = placeholder
        if !current.isEmpty {
            button.accessibilityValue = current
        }
        guard let userId = userId() else {
            button.isEnabled = false
            return button
        }
        button.showsMenuAsPrimaryAction = true
        if #available(iOS 16.0, *) {
            button.preferredMenuElementOrder = .fixed
        }
        let names = Catalog.names(kind: kind, userId: userId, in: context)
        let nameActions = names.map { name in
            UIAction(title: name, state: name == current ? .on : .off) { _ in picked(name) }
        }
        let addTitle = kind == .deckType ? "Add type…" : "Add manufacturer…"
        let addAction = UIAction(title: addTitle) { [weak self] _ in
            self?.promptAddCatalog(kind: kind, userId: userId, picked: picked)
        }
        let selection = UIMenu(options: [.displayInline, .singleSelection], children: nameActions)
        button.menu = UIMenu(children: [selection, addAction])
        return button
    }

    private func promptAddCatalog(kind: CatalogKind, userId: UUID, picked: @escaping (String) -> Void) {
        let alert = UIAlertController(
            title: kind == .deckType ? "Add type" : "Add manufacturer",
            message: nil,
            preferredStyle: .alert
        )
        alert.addTextField()
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Add", style: .default) { [weak self] _ in
            guard let self else { return }
            let result = Catalog.add(name: alert.textFields?.first?.text ?? "", kind: kind, userId: userId, in: self.context)
            switch result {
            case .added(let name):
                picked(name)
            case .duplicate:
                self.presentAlert("That name is already on the list.")
            case .blank:
                break
            }
        })
        present(alert, animated: true)
    }

    @objc private func cancelTapped() {
        dismissOrPop()
    }

    @objc private func doneTapped() {
        if let message = racking.validationMessage() {
            presentAlert(message)
            return
        }
        onDone(racking, documents)
        dismissOrPop()
    }

    private func dismissOrPop() {
        if let nav = navigationController, nav.viewControllers.first !== self {
            nav.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }

    private func presentAlert(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func presentAddDocument() {
        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Camera", style: .default) { [weak self] _ in self?.openCamera() })
        sheet.addAction(UIAlertAction(title: "Photo Library", style: .default) { [weak self] _ in self?.openLibrary() })
        sheet.addAction(UIAlertAction(title: "Files", style: .default) { [weak self] _ in self?.openFiles() })
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let pop = sheet.popoverPresentationController {
            pop.sourceView = view
            pop.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
        }
        present(sheet, animated: true)
    }

    private func openCamera() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                guard let self else { return }
                guard granted else {
                    self.presentSettingsAlert()
                    return
                }
                guard UIImagePickerController.isSourceTypeAvailable(.camera) else { return }
                let picker = UIImagePickerController()
                picker.sourceType = .camera
                picker.delegate = self
                self.present(picker, animated: true)
            }
        }
    }

    private func presentSettingsAlert() {
        let alert = UIAlertController(
            title: "Camera Access",
            message: "Enable camera access in Settings to photograph site documents.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            UIApplication.shared.open(url)
        })
        present(alert, animated: true)
    }

    private func openLibrary() {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    private func openFiles() {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.jpeg, .png, .pdf], asCopy: true)
        picker.delegate = self
        picker.allowsMultipleSelection = false
        present(picker, animated: true)
    }

    private func addDocument(data: Data, filename: String, contentType: String) {
        guard documents.count < Customer.maxSiteDocumentCount else { return }
        guard data.count <= Customer.maxSiteDocumentBytes else {
            presentAlert("Each file must be 10 MB or smaller.")
            return
        }
        guard Customer.allowedContentTypes.contains(contentType) else {
            presentAlert("Use a photo or PDF.")
            return
        }
        documents.append(SiteDocumentFile(id: nil, filename: filename, contentType: contentType, data: data))
        rebuild()
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)
        guard let image = info[.originalImage] as? UIImage,
              let data = image.jpegData(compressionQuality: 0.8) else { return }
        addDocument(data: data, filename: "site-photo.jpg", contentType: "public.jpeg")
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider else { return }
        if provider.hasItemConformingToTypeIdentifier(UTType.jpeg.identifier) {
            provider.loadDataRepresentation(forTypeIdentifier: UTType.jpeg.identifier) { [weak self] data, _ in
                DispatchQueue.main.async {
                    guard let data else { return }
                    self?.addDocument(data: data, filename: "site-photo.jpg", contentType: "public.jpeg")
                }
            }
        } else if provider.hasItemConformingToTypeIdentifier(UTType.png.identifier) {
            provider.loadDataRepresentation(forTypeIdentifier: UTType.png.identifier) { [weak self] data, _ in
                DispatchQueue.main.async {
                    guard let data else { return }
                    self?.addDocument(data: data, filename: "site-photo.png", contentType: "public.png")
                }
            }
        } else if provider.canLoadObject(ofClass: UIImage.self) {
            provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
                DispatchQueue.main.async {
                    guard let image = object as? UIImage,
                          let data = image.jpegData(compressionQuality: 0.8) else { return }
                    self?.addDocument(data: data, filename: "site-photo.jpg", contentType: "public.jpeg")
                }
            }
        }
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { return }
        let ext = url.pathExtension.lowercased()
        let type: String
        if ext == "pdf" { type = "public.pdf" }
        else if ext == "png" { type = "public.png" }
        else { type = "public.jpeg" }
        addDocument(data: data, filename: url.lastPathComponent, contentType: type)
    }

    private func previewDocument(at index: Int) {
        let file = documents[index]
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(file.filename)
        do {
            try file.data.write(to: url)
            previewURL = url
            let preview = QLPreviewController()
            preview.dataSource = self
            present(preview, animated: true)
        } catch {
            presentAlert("Could not open that file.")
        }
    }

    func numberOfPreviewItems(in controller: QLPreviewController) -> Int { previewURL == nil ? 0 : 1 }

    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        (previewURL ?? FileManager.default.temporaryDirectory) as QLPreviewItem
    }
}
