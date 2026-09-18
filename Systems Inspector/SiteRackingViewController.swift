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

    private let scrollView = UIScrollView()
    private let stackView = UIStackView()

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
        title = "Site racking"
        view.backgroundColor = AppTheme.background
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
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(stackView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -20),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40)
        ])
        rebuild()
    }

    private func ensurePlaceholderRows() {
        if racking.uprights.rows.isEmpty {
            racking.uprights.rows = [UprightSpec(manufacturer: "")]
        }
        if racking.beams.rows.isEmpty {
            racking.beams.rows = [BeamSpec(manufacturer: "")]
        }
        if racking.decks.rows.isEmpty {
            racking.decks.rows = [DeckSpec(manufacturer: "", type: "")]
        }
        if racking.crossBars.rows.isEmpty {
            racking.crossBars.rows = [CrossBarSpec(manufacturer: "")]
        }
        if racking.anchors.rows.isEmpty {
            racking.anchors.rows = [AnchorSpec(manufacturer: "")]
        }
        if racking.rowSpacers.rows.isEmpty {
            racking.rowSpacers.rows = [RowSpacerSpec(manufacturer: "")]
        }
    }

    private func rebuild() {
        stackView.arrangedSubviews.forEach {
            stackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        stackView.addArrangedSubview(sectionLabel("Site Information"))
        stackView.addArrangedSubview(siteInformationCard())
        stackView.addArrangedSubview(sectionLabel("Load Information"))
        stackView.addArrangedSubview(loadInformationCard())
        stackView.addArrangedSubview(sectionLabel("Site documents"))
        stackView.addArrangedSubview(documentsView())
        stackView.addArrangedSubview(componentSection(
            title: "Upright Frames",
            mode: racking.uprights.mode,
            canStandardize: racking.canSetUprightsStandardized(),
            addEnabled: racking.uprights.mode == .mixed,
            onMode: { [weak self] mixed in self?.setUprightsMixed(mixed) },
            onAdd: { [weak self] in
                self?.racking.uprights.rows.append(UprightSpec(manufacturer: ""))
                self?.rebuild()
            }
        ))
        for index in racking.uprights.rows.indices {
            stackView.addArrangedSubview(uprightCard(index: index))
        }
        stackView.addArrangedSubview(componentSection(
            title: "Beams",
            mode: racking.beams.mode,
            canStandardize: racking.canSetBeamsStandardized(),
            addEnabled: racking.beams.mode == .mixed,
            onMode: { [weak self] mixed in self?.setBeamsMixed(mixed) },
            onAdd: { [weak self] in
                self?.racking.beams.rows.append(BeamSpec(manufacturer: ""))
                self?.rebuild()
            }
        ))
        for index in racking.beams.rows.indices {
            stackView.addArrangedSubview(beamCard(index: index))
        }
        stackView.addArrangedSubview(componentSection(
            title: "Wire Decks",
            mode: racking.decks.mode,
            canStandardize: racking.canSetDecksStandardized(),
            addEnabled: racking.decks.mode == .mixed,
            onMode: { [weak self] mixed in self?.setDecksMixed(mixed) },
            onAdd: { [weak self] in
                self?.racking.decks.rows.append(DeckSpec(manufacturer: "", type: ""))
                self?.rebuild()
            }
        ))
        for index in racking.decks.rows.indices {
            stackView.addArrangedSubview(deckCard(index: index))
        }
        stackView.addArrangedSubview(componentSection(
            title: "Cross Bars",
            mode: racking.crossBars.mode,
            canStandardize: racking.canSetCrossBarsStandardized(),
            addEnabled: racking.crossBars.mode == .mixed,
            onMode: { [weak self] mixed in self?.setCrossBarsMixed(mixed) },
            onAdd: { [weak self] in
                self?.racking.crossBars.rows.append(CrossBarSpec(manufacturer: ""))
                self?.rebuild()
            }
        ))
        for index in racking.crossBars.rows.indices {
            stackView.addArrangedSubview(crossBarCard(index: index))
        }
        stackView.addArrangedSubview(sectionLabel("Safety Clips"))
        stackView.addArrangedSubview(safetyClipsCard())
        stackView.addArrangedSubview(componentSection(
            title: "Anchors",
            mode: racking.anchors.mode,
            canStandardize: racking.canSetAnchorsStandardized(),
            addEnabled: racking.anchors.mode == .mixed,
            onMode: { [weak self] mixed in self?.setAnchorsMixed(mixed) },
            onAdd: { [weak self] in
                self?.racking.anchors.rows.append(AnchorSpec(manufacturer: ""))
                self?.rebuild()
            }
        ))
        for index in racking.anchors.rows.indices {
            stackView.addArrangedSubview(anchorCard(index: index))
        }
        stackView.addArrangedSubview(componentSection(
            title: "Row Spacers",
            mode: racking.rowSpacers.mode,
            canStandardize: racking.canSetRowSpacersStandardized(),
            addEnabled: racking.rowSpacers.mode == .mixed,
            onMode: { [weak self] mixed in self?.setRowSpacersMixed(mixed) },
            onAdd: { [weak self] in
                self?.racking.rowSpacers.rows.append(RowSpacerSpec(manufacturer: ""))
                self?.rebuild()
            }
        ))
        for index in racking.rowSpacers.rows.indices {
            stackView.addArrangedSubview(rowSpacerCard(index: index))
        }
    }

    private func setUprightsMixed(_ mixed: Bool) {
        if !mixed && !racking.canSetUprightsStandardized() { rebuild(); return }
        racking.uprights.mode = mixed ? .mixed : .standardized
        rebuild()
    }

    private func setBeamsMixed(_ mixed: Bool) {
        if !mixed && !racking.canSetBeamsStandardized() { rebuild(); return }
        racking.beams.mode = mixed ? .mixed : .standardized
        rebuild()
    }

    private func setDecksMixed(_ mixed: Bool) {
        if !mixed && !racking.canSetDecksStandardized() { rebuild(); return }
        racking.decks.mode = mixed ? .mixed : .standardized
        rebuild()
    }

    private func setCrossBarsMixed(_ mixed: Bool) {
        if !mixed && !racking.canSetCrossBarsStandardized() { rebuild(); return }
        racking.crossBars.mode = mixed ? .mixed : .standardized
        rebuild()
    }

    private func setAnchorsMixed(_ mixed: Bool) {
        if !mixed && !racking.canSetAnchorsStandardized() { rebuild(); return }
        racking.anchors.mode = mixed ? .mixed : .standardized
        rebuild()
    }

    private func setRowSpacersMixed(_ mixed: Bool) {
        if !mixed && !racking.canSetRowSpacersStandardized() { rebuild(); return }
        racking.rowSpacers.mode = mixed ? .mixed : .standardized
        rebuild()
    }

    private func sectionLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = AppTheme.fontBold(.subheadline)
        label.textColor = AppTheme.textSecondary
        return label
    }

    private func componentSection(
        title: String,
        mode: SiteRackingMode,
        canStandardize: Bool,
        addEnabled: Bool,
        onMode: @escaping (Bool) -> Void,
        onAdd: @escaping () -> Void
    ) -> UIView {
        let header = UIStackView()
        header.axis = .horizontal
        header.spacing = 8
        header.alignment = .center
        let label = sectionLabel(title)
        let control = UISegmentedControl(items: ["Standardized", "Mixed"])
        control.selectedSegmentIndex = mode == .mixed ? 1 : 0
        control.isEnabled = mode == .mixed ? canStandardize || true : true
        if mode == .mixed && !canStandardize {
            // Keep Mixed selected; Standardized tap is ignored in onMode.
        }
        control.addAction(UIAction { _ in
            onMode(control.selectedSegmentIndex == 1)
        }, for: .valueChanged)
        header.addArrangedSubview(label)
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
        let spec = racking.uprights.rows[index]
        return specCard(
            manufacturer: spec.manufacturer,
            fields: [
                ("Type", spec.type),
                ("Height", spec.height),
                ("Depth", spec.depth),
                ("Capacity", spec.capacity)
            ],
            footerControl: constructionToggle(spec.construction) { [weak self] construction in
                self?.racking.uprights.rows[index].construction = construction
            },
            onManufacturer: { [weak self] name in
                self?.racking.uprights.rows[index].manufacturer = name
                self?.rebuild()
            },
            onField: { [weak self] fieldIndex, text in
                switch fieldIndex {
                case 0: self?.racking.uprights.rows[index].type = Self.optionalText(text)
                case 1: self?.racking.uprights.rows[index].height = Self.optionalText(text)
                case 2: self?.racking.uprights.rows[index].depth = Self.optionalText(text)
                default: self?.racking.uprights.rows[index].capacity = Self.optionalText(text)
                }
            }
        )
    }

    private func beamCard(index: Int) -> UIView {
        let spec = racking.beams.rows[index]
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
                self?.racking.beams.rows[index].manufacturer = name
                self?.rebuild()
            },
            onField: { [weak self] fieldIndex, text in
                switch fieldIndex {
                case 0: self?.racking.beams.rows[index].type = Self.optionalText(text)
                case 1: self?.racking.beams.rows[index].length = Self.optionalText(text)
                case 2: self?.racking.beams.rows[index].face = Self.optionalText(text)
                case 3: self?.racking.beams.rows[index].stepDimensions = Self.optionalText(text)
                default: self?.racking.beams.rows[index].capacity = Self.optionalText(text)
                }
            }
        )
    }

    private func deckCard(index: Int) -> UIView {
        let spec = racking.decks.rows[index]
        let card = UIStackView()
        card.axis = .vertical
        card.spacing = 8
        card.addArrangedSubview(catalogPullDown(
            kind: .wireDeckManufacturer,
            current: spec.manufacturer,
            placeholder: "Manufacturer"
        ) { [weak self] name in
            self?.racking.decks.rows[index].manufacturer = name
            self?.rebuild()
        })
        card.addArrangedSubview(textField(placeholder: "Capacity", text: spec.capacity) { [weak self] text in
            self?.racking.decks.rows[index].capacity = Self.optionalText(text)
        })
        card.addArrangedSubview(catalogPullDown(
            kind: .deckType,
            current: spec.type,
            placeholder: "Type"
        ) { [weak self] type in
            self?.racking.decks.rows[index].type = type
            self?.rebuild()
        })
        card.addArrangedSubview(yesNoToggle(title: "UDL", isOn: spec.udl, accessibilityLabel: "UDL") { [weak self] isOn in
            self?.racking.decks.rows[index].udl = isOn
            self?.rebuild()
        })
        card.addArrangedSubview(textField(placeholder: "Number of Decks", text: spec.numberOfDecks) { [weak self] text in
            self?.racking.decks.rows[index].numberOfDecks = Self.optionalText(text)
        })
        return card
    }

    private func crossBarCard(index: Int) -> UIView {
        let spec = racking.crossBars.rows[index]
        return specCard(
            manufacturer: spec.manufacturer,
            fields: [("Size", spec.size)],
            onManufacturer: { [weak self] name in
                self?.racking.crossBars.rows[index].manufacturer = name
                self?.rebuild()
            },
            onField: { [weak self] _, text in
                self?.racking.crossBars.rows[index].size = Self.optionalText(text)
            }
        )
    }

    private func anchorCard(index: Int) -> UIView {
        let spec = racking.anchors.rows[index]
        return specCard(
            manufacturer: spec.manufacturer,
            fields: [("Size", spec.size)],
            onManufacturer: { [weak self] name in
                self?.racking.anchors.rows[index].manufacturer = name
                self?.rebuild()
            },
            onField: { [weak self] _, text in
                self?.racking.anchors.rows[index].size = Self.optionalText(text)
            }
        )
    }

    private func rowSpacerCard(index: Int) -> UIView {
        let spec = racking.rowSpacers.rows[index]
        return specCard(
            manufacturer: spec.manufacturer,
            fields: [
                ("Length", spec.length),
                ("Width", spec.width)
            ],
            onManufacturer: { [weak self] name in
                self?.racking.rowSpacers.rows[index].manufacturer = name
                self?.rebuild()
            },
            onField: { [weak self] fieldIndex, text in
                if fieldIndex == 0 {
                    self?.racking.rowSpacers.rows[index].length = Self.optionalText(text)
                } else {
                    self?.racking.rowSpacers.rows[index].width = Self.optionalText(text)
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
