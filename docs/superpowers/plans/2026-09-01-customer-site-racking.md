# Customer SiteRacking Implementation Plan

> **Status:** Shipped. The checkboxes below are not a live tracker.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a Customer hold optional SiteDocuments (≤5 photos/PDFs) and optional SiteRacking (uprights/beams/decks) on iOS, via CustomerFormState and CustomerIntake.

**Architecture:** SiteRacking is a Codable value encoded as optional `siteRackingJSON` on Customer. SiteDocument is a to-many Core Data entity with bytes + filename. Manufacturer and DeckType names live in CatalogName (kind + name + userId), seeded add-only per Session user. One SiteRackingViewController edits a copy; Add/Edit pushes it; Details presents it and Intake-saves on Done.

**Tech Stack:** UIKit, Core Data + CloudKit (`NSPersistentCloudKitContainer`), XCTest in-memory stores, Xcode class codegen for entities.

**Spec:** `docs/superpowers/specs/2026-09-01-customer-site-racking-design.md`

## Global Constraints

- iOS only; do not change `webapp/frontend/src/services/customerCodec.ts`
- ReportSnapshot Customer fields stay id, name, site, address
- SiteRacking is not Issues; do not touch Issue paths or InspectionItem flags
- At most 5 SiteDocuments; JPEG/PNG/PDF only; 10 MB per file at pick time
- Camera JPEG compression quality 0.8 (same as InspectionItem)
- Catalogs are this Session user’s list, not company-wide
- Pair rule: Uprights recorded ↔ Beams recorded; Decks optional
- `CustomerFormState.isValid` remains name-only
- Empty SiteRacking persists as `nil` JSON, not `{}`
- Keep-by-id must not rewrite SiteDocument `data` on name-only Customer save
- Language: `CONTEXT.md` — SiteRacking, SiteDocument, Manufacturer, DeckType
- New `.swift` files under `Systems Inspector/` and `Systems InspectorTests/` are picked up by `PBXFileSystemSynchronizedRootGroup` (do not edit `project.pbxproj` for those)
- Do not commit unless the user asks

---

## File map

| File | Responsibility |
|------|----------------|
| `Systems Inspector/SiteRacking.swift` | Value types, JSON, pair/row rules, `canSetStandardized` |
| `Systems Inspector/Catalog.swift` | Seed, list, add CatalogName |
| `Systems Inspector/SiteDocumentFile.swift` | `SiteDocumentFile` struct (id, filename, contentType, data) |
| `Systems Inspector/Customer+SiteDocuments.swift` | `documentFiles()`, `replaceDocuments(_:userId:)` |
| `Systems Inspector/Systems_Inspector.xcdatamodeld/.../contents` | `siteRackingJSON`, SiteDocument, CatalogName |
| `Systems Inspector/CustomerFormState.swift` | Add `siteRacking`, `siteDocuments` |
| `Systems Inspector/CustomerIntake.swift` | Persist/hydrate JSON + documents |
| `Systems Inspector/SiteRackingViewController.swift` | Sheet UI |
| `Systems Inspector/CustomerFormViewController.swift` | Button + push |
| `Systems Inspector/CustomerDetailsViewController.swift` | Header summary + sheet + Intake on Done |
| `Systems InspectorTests/SiteRackingTests.swift` | Rules + JSON |
| `Systems InspectorTests/CatalogTests.swift` | Seed, de-dupe, userId scope |
| `Systems InspectorTests/CustomerSiteDocumentTests.swift` | Cap, keep-by-id |
| `Systems InspectorTests/CustomerIntakeTests.swift` | Extend round-trip |
| `Systems InspectorTests/CustomerFormStateTests.swift` | isValid ignores spec/docs |

---

### Task 1: SiteRacking value type

**Files:**
- Create: `Systems Inspector/SiteRacking.swift`
- Test: `Systems InspectorTests/SiteRackingTests.swift`

**Interfaces:**
- Consumes: nothing
- Produces:

```swift
enum SiteRackingMode: String, Codable, Equatable {
    case standardized
    case mixed
}

struct UprightSpec: Codable, Equatable {
    var manufacturer: String
    var height: String?
    var depth: String?
    var color: String?
}

struct BeamSpec: Codable, Equatable {
    var manufacturer: String
    var length: String?
    var color: String?
}

struct DeckSpec: Codable, Equatable {
    var manufacturer: String
    var type: String
    var size: String?
}

struct SiteRackingSection<Row: Codable & Equatable>: Codable, Equatable {
    var mode: SiteRackingMode
    var rows: [Row]
}

struct SiteRacking: Codable, Equatable {
    var uprights: SiteRackingSection<UprightSpec>
    var beams: SiteRackingSection<BeamSpec>
    var decks: SiteRackingSection<DeckSpec>

    static var empty: SiteRacking { /* three standardized sections, empty rows */ }

    var isEmpty: Bool { /* no type recorded */ }
    var uprightsRecorded: Bool
    var beamsRecorded: Bool
    var decksRecorded: Bool

    func canSetUprightsStandardized() -> Bool { uprights.rows.count <= 1 }
    func canSetBeamsStandardized() -> Bool { beams.rows.count <= 1 }
    func canSetDecksStandardized() -> Bool { decks.rows.count <= 1 }

    /// nil if Done may succeed
    func validationMessage() -> String?
    func jsonData() -> Data?
    static func from(jsonData: Data?) -> SiteRacking
}
```

A type is recorded when ≥1 row has a non-empty trimmed manufacturer. `from(jsonData: nil)` and invalid data return `.empty`. `jsonData()` returns `nil` when `isEmpty`. Optional strings: omit empty from encoding (decode missing as nil). `DeckSpec.type` may be `""` on an unrecorded placeholder row; a recorded deck without type fails validation.

`validationMessage()` copy:
- Uprights recorded, beams not: `"Beams are required when Uprights are recorded."`
- Beams recorded, uprights not: `"Uprights are required when Beams are recorded."`
- Recorded upright/beam missing manufacturer: `"Each recorded row needs a manufacturer."`
- Recorded deck missing type: `"Each deck needs a type."`

- [ ] **Step 1: Write the failing tests**

Create `Systems InspectorTests/SiteRackingTests.swift`:

```swift
import XCTest
@testable import Systems_Inspector

final class SiteRackingTests: XCTestCase {
    func testEmptyJSONRoundTripIsNil() {
        XCTAssertTrue(SiteRacking.empty.isEmpty)
        XCTAssertNil(SiteRacking.empty.jsonData())
        XCTAssertEqual(SiteRacking.from(jsonData: nil), .empty)
    }

    func testUprightsOnlyIsInvalid() {
        var spec = SiteRacking.empty
        spec.uprights.rows = [UprightSpec(manufacturer: "Interlake")]
        XCTAssertEqual(
            spec.validationMessage(),
            "Beams are required when Uprights are recorded."
        )
    }

    func testBeamsOnlyIsInvalid() {
        var spec = SiteRacking.empty
        spec.beams.rows = [BeamSpec(manufacturer: "Interlake")]
        XCTAssertEqual(
            spec.validationMessage(),
            "Uprights are required when Beams are recorded."
        )
    }

    func testPairedUprightsAndBeamsValid() {
        var spec = SiteRacking.empty
        spec.uprights.rows = [UprightSpec(manufacturer: "Interlake")]
        spec.beams.rows = [BeamSpec(manufacturer: "Interlake")]
        XCTAssertNil(spec.validationMessage())
        XCTAssertFalse(spec.isEmpty)
    }

    func testDecksOnlyIsValid() {
        var spec = SiteRacking.empty
        spec.decks.rows = [DeckSpec(manufacturer: "Interlake", type: "wire")]
        XCTAssertNil(spec.validationMessage())
    }

    func testDeckWithoutTypeIsInvalid() {
        var spec = SiteRacking.empty
        spec.decks.rows = [DeckSpec(manufacturer: "Interlake", type: "")]
        XCTAssertEqual(spec.validationMessage(), "Each deck needs a type.")
    }

    func testCanSetStandardizedFalseWhenTwoRows() {
        var spec = SiteRacking.empty
        spec.uprights.mode = .mixed
        spec.uprights.rows = [
            UprightSpec(manufacturer: "A"),
            UprightSpec(manufacturer: "B")
        ]
        XCTAssertFalse(spec.canSetUprightsStandardized())
        spec.uprights.rows.removeLast()
        XCTAssertTrue(spec.canSetUprightsStandardized())
    }

    func testJSONRoundTripPreservesFields() {
        var spec = SiteRacking.empty
        spec.uprights.mode = .mixed
        spec.uprights.rows = [
            UprightSpec(manufacturer: "Interlake", height: "16'", depth: "42\"", color: "orange")
        ]
        spec.beams.rows = [BeamSpec(manufacturer: "Interlake", length: "8'", color: "orange")]
        spec.decks.rows = [DeckSpec(manufacturer: "Interlake", type: "wire", size: "42x46")]
        let data = spec.jsonData()
        XCTAssertNotNil(data)
        XCTAssertEqual(SiteRacking.from(jsonData: data), spec)
    }

    func testInvalidJSONYieldsEmpty() {
        XCTAssertEqual(SiteRacking.from(jsonData: Data("nope".utf8)), .empty)
    }
}
```

- [ ] **Step 2: Run tests, expect compile failure** (type `SiteRacking` missing)

Run:

```
xcodebuild test -scheme "Systems Inspector" -destination "platform=iOS Simulator,name=iPhone 16" -only-testing:"Systems InspectorTests/SiteRackingTests" -quiet
```

If the simulator name differs, use `xcrun simctl list devices available`. Expected: compile error, `SiteRacking` not found.

- [ ] **Step 3: Implement `SiteRacking.swift`**

Put the types above in `Systems Inspector/SiteRacking.swift`. Implementation notes:

- `SiteRackingSection` needs an explicit `init(mode:rows:)` because we cannot rely on synthesized memberwise init across files the same way for generic Codable; implement `init(mode: SiteRackingMode = .standardized, rows: [Row] = [])`.
- `empty` = three sections, mode standardized, `rows: []`.
- Recorded: `rows.contains { !$0.manufacturer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }` — add a small protocol:

```swift
protocol SiteRackingRow {
    var manufacturer: String { get }
}
```

Conform `UprightSpec`, `BeamSpec`, `DeckSpec`. For decks, also require non-empty trimmed `type` when recorded.

- Encode with `JSONEncoder`; decode with `JSONDecoder`.
- Check pair rule before per-row manufacturer/type messages so tests’ uprights-only / beams-only strings match.

- [ ] **Step 4: Re-run SiteRackingTests — all PASS**

- [ ] **Step 5: Commit** (skip unless user asked)

```
git add "Systems Inspector/SiteRacking.swift" "Systems InspectorTests/SiteRackingTests.swift"
git commit -m "feat(customer): SiteRacking value type and pair-rule validation"
```

---

### Task 2: Core Data model

**Files:**
- Modify: `Systems Inspector/Systems_Inspector.xcdatamodeld/Systems_Inspector.xcdatamodel/contents`
- Test: `Systems InspectorTests/CatalogTests.swift` (first test only: in-memory store loads with new entities)

**Interfaces:**
- Consumes: none
- Produces: codegen classes `SiteDocument`, `CatalogName`; `Customer.siteRackingJSON: Data?`; `Customer.siteDocuments`; `SiteDocument.customer`

TDD exception: the `.xcdatamodel` XML is configuration. The failing test is “in-memory container loads and we can insert CatalogName / SiteDocument”.

On Customer entity, add (keep attributes alphabetically if the file already is):

```xml
<attribute name="siteRackingJSON" optional="YES" attributeType="Binary"/>
<relationship name="siteDocuments" optional="YES" toMany="YES" deletionRule="Cascade" destinationEntity="SiteDocument" inverseName="customer" inverseEntity="SiteDocument"/>
```

After the Customer `</entity>` (before Inspection), insert:

```xml
    <entity name="CatalogName" representedClassName=".CatalogName" syncable="YES" codeGenerationType="class">
        <attribute name="id" optional="YES" attributeType="UUID" usesScalarValueType="NO"/>
        <attribute name="kind" optional="YES" attributeType="String"/>
        <attribute name="name" optional="YES" attributeType="String"/>
        <attribute name="userId" optional="YES" attributeType="UUID" usesScalarValueType="NO"/>
        <fetchIndex name="byUserIdKindIndex">
            <fetchIndexElement property="userId" type="Binary" order="ascending"/>
            <fetchIndexElement property="kind" type="Binary" order="ascending"/>
        </fetchIndex>
    </entity>
    <entity name="SiteDocument" representedClassName=".SiteDocument" syncable="YES" codeGenerationType="class">
        <attribute name="contentType" optional="YES" attributeType="String"/>
        <attribute name="data" optional="YES" attributeType="Binary" allowsExternalBinaryDataStorage="YES"/>
        <attribute name="filename" optional="YES" attributeType="String"/>
        <attribute name="id" optional="YES" attributeType="UUID" usesScalarValueType="NO"/>
        <attribute name="sortIndex" optional="YES" attributeType="Integer 32" defaultValueString="0" usesScalarValueType="YES"/>
        <attribute name="userId" optional="YES" attributeType="UUID" usesScalarValueType="NO"/>
        <relationship name="customer" optional="YES" maxCount="1" deletionRule="Nullify" destinationEntity="Customer" inverseName="siteDocuments" inverseEntity="Customer"/>
    </entity>
```

Do not add document slot attributes on Customer. Do not set uniqueness constraints (CloudKit).

- [ ] **Step 1: Write failing test** in `CatalogTests.swift`:

```swift
import CoreData
import XCTest
@testable import Systems_Inspector

final class CatalogTests: XCTestCase {
    var container: NSPersistentContainer!
    var context: NSManagedObjectContext!

    override func setUp() {
        super.setUp()
        guard let model = NSManagedObjectModel.mergedModel(from: [Bundle(for: CoreDataManager.self)]) else {
            XCTFail("Missing Core Data model")
            return
        }
        container = NSPersistentContainer(name: "Systems_Inspector", managedObjectModel: model)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        description.shouldAddStoreAsynchronously = false
        container.persistentStoreDescriptions = [description]
        var loadError: Error?
        container.loadPersistentStores { _, error in loadError = error }
        XCTAssertNil(loadError)
        context = container.viewContext
    }

    override func tearDown() {
        context = nil
        container = nil
        super.tearDown()
    }

    func testModelIncludesCatalogNameAndSiteDocument() {
        XCTAssertNotNil(container.managedObjectModel.entitiesByName["CatalogName"])
        XCTAssertNotNil(container.managedObjectModel.entitiesByName["SiteDocument"])
        let customer = Customer(context: context)
        customer.siteRackingJSON = Data("{}".utf8)
        XCTAssertEqual(customer.siteRackingJSON, Data("{}".utf8))
        let doc = SiteDocument(context: context)
        doc.id = UUID()
        doc.customer = customer
        XCTAssertEqual(customer.siteDocuments?.count, 1)
    }
}
```

- [ ] **Step 2: Run CatalogTests — expect failure** (`CatalogName` / `SiteDocument` unknown or `siteRackingJSON` not on Customer)

- [ ] **Step 3: Edit the xcdatamodel contents as above**

- [ ] **Step 4: Re-run CatalogTests `testModelIncludesCatalogNameAndSiteDocument` — PASS** (codegen classes appear after the test target compiles against the updated model)

- [ ] **Step 5: Commit** (skip unless asked)

---

### Task 3: Catalog module

**Files:**
- Create: `Systems Inspector/Catalog.swift`
- Test: `Systems InspectorTests/CatalogTests.swift` (add tests below)

**Interfaces:**
- Consumes: `CatalogName` entity, `userId: UUID`
- Produces:

```swift
enum CatalogKind: String {
    case manufacturer
    case deckType
}

enum CatalogAddResult: Equatable {
    case added(String)
    case duplicate
    case blank
}

enum Catalog {
    static let manufacturerSeed: [String] = [
        "Interlake", "Ridg-U-Rak", "Mecalux", "Steel King",
        "UNARCO", "Hannibal", "Speedrack", "Frazier", "Teardrop (generic)"
    ]
    static let deckTypeSeed: [String] = ["wire", "particle", "bar grate", "other"]

    static func names(kind: CatalogKind, userId: UUID, in context: NSManagedObjectContext) -> [String]
    static func add(name: String, kind: CatalogKind, userId: UUID, in context: NSManagedObjectContext) -> CatalogAddResult
}
```

`names`: fetch `CatalogName` where `userId` and `kind.rawValue`. If count is 0, insert seed (new UUID per row, `kind`, `name`, `userId`), save not required if caller saves — still insert into `context`. Return names sorted with `localizedStandardCompare`.

`add`: trim; empty → `.blank`. If any existing name for that user+kind has `caseInsensitiveCompare == .orderedSame` → `.duplicate`. Else insert and return `.added(trimmed)`.

- [ ] **Step 1: Add failing tests** to `CatalogTests.swift`:

```swift
    func testFirstFetchSeedsManufacturers() {
        let userId = UUID()
        let names = Catalog.names(kind: .manufacturer, userId: userId, in: context)
        XCTAssertEqual(names, Catalog.manufacturerSeed.sorted { $0.localizedStandardCompare($1) == .orderedAscending })
        _ = Catalog.names(kind: .manufacturer, userId: userId, in: context)
        let request = CatalogName.fetchRequest()
        request.predicate = NSPredicate(format: "userId == %@ AND kind == %@", userId as CVarArg, "manufacturer")
        XCTAssertEqual(try context.count(for: request), Catalog.manufacturerSeed.count)
    }

    func testSeedIsScopedByUser() {
        let a = UUID()
        let b = UUID()
        _ = Catalog.names(kind: .deckType, userId: a, in: context)
        _ = Catalog.names(kind: .deckType, userId: b, in: context)
        let request = CatalogName.fetchRequest()
        request.predicate = NSPredicate(format: "kind == %@", "deckType")
        XCTAssertEqual(try context.count(for: request), Catalog.deckTypeSeed.count * 2)
    }

    func testAddDeDupesCaseInsensitive() {
        let userId = UUID()
        _ = Catalog.names(kind: .manufacturer, userId: userId, in: context)
        XCTAssertEqual(Catalog.add(name: "  interlake  ", kind: .manufacturer, userId: userId, in: context), .duplicate)
        XCTAssertEqual(Catalog.add(name: "   ", kind: .manufacturer, userId: userId, in: context), .blank)
        XCTAssertEqual(Catalog.add(name: " CustomCo ", kind: .manufacturer, userId: userId, in: context), .added("CustomCo"))
        XCTAssertTrue(Catalog.names(kind: .manufacturer, userId: userId, in: context).contains("CustomCo"))
    }
```

- [ ] **Step 2: Run CatalogTests — expect `Catalog` missing**

- [ ] **Step 3: Implement `Catalog.swift`**

- [ ] **Step 4: Re-run CatalogTests — PASS**

- [ ] **Step 5: Commit** (skip unless asked)

---

### Task 4: SiteDocument files API

**Files:**
- Create: `Systems Inspector/SiteDocumentFile.swift`
- Create: `Systems Inspector/Customer+SiteDocuments.swift`
- Test: `Systems InspectorTests/CustomerSiteDocumentTests.swift`

**Interfaces:**
- Consumes: `SiteDocument` entity, `Customer.siteDocuments`
- Produces:

```swift
struct SiteDocumentFile: Equatable {
    var id: UUID?
    var filename: String
    var contentType: String
    var data: Data
}

extension Customer {
    static let maxSiteDocumentCount = 5
    static let allowedContentTypes: Set<String> = ["public.jpeg", "public.png", "public.pdf"]
    static let maxSiteDocumentBytes = 10 * 1024 * 1024

    func documentFiles() -> [SiteDocumentFile]
    func replaceDocuments(_ files: [SiteDocumentFile], userId: UUID)
}
```

`documentFiles()`: sort relationship by `sortIndex` ascending; skip rows with nil data; map id/filename/contentType/data.

`replaceDocuments`:
1. `let limited = Array(files.prefix(maxSiteDocumentCount))`
2. Build `Set` of keep ids (`limited.compactMap(\.id)`)
3. For each existing `SiteDocument` in the relationship: if its `id` is not in keep, `context.delete`
4. For each file in `limited.enumerated()`:
   - if `id` matches an existing document: set `sortIndex`, `filename`, `contentType`; **do not assign `data`**
   - if `id` is nil or not found: insert `SiteDocument` with new UUID, `data`, `filename`, `contentType`, `userId`, `sortIndex`, `customer`

Use in-memory container like `CustomerIntakeTests`.

- [ ] **Step 1: Write failing tests**

```swift
func testReplaceCapsAtFive() {
    let customer = makeCustomer()
    let files = (0..<6).map { i in
        SiteDocumentFile(id: nil, filename: "f\(i).pdf", contentType: "public.pdf", data: Data([UInt8(i)]))
    }
    customer.replaceDocuments(files, userId: UUID())
    XCTAssertEqual(customer.documentFiles().count, 5)
    XCTAssertEqual(customer.documentFiles().map(\.filename), ["f0.pdf","f1.pdf","f2.pdf","f3.pdf","f4.pdf"])
}

func testKeepByIdDoesNotRewriteData() {
    let userId = UUID()
    let customer = makeCustomer()
    let original = Data([1, 2, 3])
    customer.replaceDocuments([
        SiteDocumentFile(id: nil, filename: "a.jpg", contentType: "public.jpeg", data: original)
    ], userId: userId)
    let id = customer.documentFiles()[0].id
    XCTAssertNotNil(id)
    customer.replaceDocuments([
        SiteDocumentFile(id: id, filename: "a.jpg", contentType: "public.jpeg", data: Data([9, 9, 9]))
    ], userId: userId)
    XCTAssertEqual(customer.documentFiles()[0].data, original)
}

func testMissingIdDeletesDocument() {
    let customer = makeCustomer()
    customer.replaceDocuments([
        SiteDocumentFile(id: nil, filename: "a.pdf", contentType: "public.pdf", data: Data([1])),
        SiteDocumentFile(id: nil, filename: "b.pdf", contentType: "public.pdf", data: Data([2]))
    ], userId: UUID())
    let keep = customer.documentFiles()[0]
    customer.replaceDocuments([keep], userId: UUID())
    XCTAssertEqual(customer.documentFiles().map(\.filename), [keep.filename])
}
```

- [ ] **Step 2: Run — expect `SiteDocumentFile` / `replaceDocuments` missing**

- [ ] **Step 3: Implement the two Swift files**

- [ ] **Step 4: Re-run CustomerSiteDocumentTests — PASS**

- [ ] **Step 5: Commit** (skip unless asked)

---

### Task 5: CustomerFormState + CustomerIntake

**Files:**
- Modify: `Systems Inspector/CustomerFormState.swift`
- Modify: `Systems Inspector/CustomerIntake.swift`
- Modify: `Systems InspectorTests/CustomerFormStateTests.swift`
- Modify: `Systems InspectorTests/CustomerIntakeTests.swift`

**Interfaces:**
- Consumes: `SiteRacking`, `SiteDocumentFile`, `Customer.documentFiles()`, `Customer.replaceDocuments`, `Customer.siteRackingJSON`
- Produces: `CustomerFormState.siteRacking`, `CustomerFormState.siteDocuments`; Intake create/update/hydrate persist them

```swift
struct CustomerFormState {
    var name: String = ""
    // existing fields unchanged
    var siteRacking: SiteRacking = .empty
    var siteDocuments: [SiteDocumentFile] = []
    var isValid: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}
```

Intake `applyFields`:
- existing string fields unchanged
- `customer.siteRackingJSON = form.siteRacking.jsonData()`
- `customer.replaceDocuments(form.siteDocuments, userId: customer.userId ?? UserManager.shared.sessionUserId ?? UUID())` — prefer `customer.userId`

`formState(from:)`:
- existing fields
- `siteRacking: SiteRacking.from(jsonData: customer.siteRackingJSON)`
- `siteDocuments: customer.documentFiles()`

Do not clear spec/docs when only name/address change.

- [ ] **Step 1: Failing tests**

`CustomerFormStateTests`:

```swift
func testSpecAndDocsDoNotAffectValidity() {
    var form = CustomerFormState()
    form.siteRacking.uprights.rows = [UprightSpec(manufacturer: "X")]
    form.siteDocuments = [
        SiteDocumentFile(id: nil, filename: "a.pdf", contentType: "public.pdf", data: Data([1]))
    ]
    XCTAssertFalse(form.isValid)
    form.name = "Acme"
    XCTAssertTrue(form.isValid)
}
```

`CustomerIntakeTests` (session + in-memory context already there):

```swift
func testCreateHydrateUpdateSiteRackingAndDocuments() {
    let userId = UUID()
    UserManager.shared.startSession(userId: userId)
    var form = CustomerFormState(name: "Acme")
    form.siteRacking.uprights.rows = [UprightSpec(manufacturer: "Interlake", height: "16'")]
    form.siteRacking.beams.rows = [BeamSpec(manufacturer: "Interlake")]
    form.siteDocuments = [
        SiteDocumentFile(id: nil, filename: "plan.pdf", contentType: "public.pdf", data: Data([0x25, 0x50, 0x44, 0x46]))
    ]
    let customer = CustomerIntake.create(form: form, in: context)
    XCTAssertNotNil(customer?.siteRackingJSON)
    XCTAssertEqual(customer?.documentFiles().count, 1)

    var loaded = CustomerIntake.formState(from: customer!)
    XCTAssertEqual(loaded.siteRacking.uprights.rows.first?.manufacturer, "Interlake")
    XCTAssertEqual(loaded.siteDocuments.first?.filename, "plan.pdf")
    XCTAssertEqual(loaded.siteDocuments.first?.data, Data([0x25, 0x50, 0x44, 0x46]))
    let docId = loaded.siteDocuments[0].id
    XCTAssertNotNil(docId)

    loaded.name = "Acme 2"
    XCTAssertTrue(CustomerIntake.update(customer!, form: loaded))
    XCTAssertEqual(customer!.name, "Acme 2")
    XCTAssertEqual(customer!.documentFiles()[0].data, Data([0x25, 0x50, 0x44, 0x46]))
    XCTAssertEqual(customer!.documentFiles()[0].id, docId)
}
```

- [ ] **Step 2: Run those tests — FAIL** (properties missing)

- [ ] **Step 3: Extend FormState + Intake as specified**

- [ ] **Step 4: Re-run CustomerFormStateTests and CustomerIntakeTests — PASS**

- [ ] **Step 5: Commit** (skip unless asked)

---

### Task 6: SiteRackingViewController

**Files:**
- Create: `Systems Inspector/SiteRackingViewController.swift`
- Modify: `Systems Inspector.xcodeproj/project.pbxproj` camera usage string only (Debug + Release):
  `INFOPLIST_KEY_NSCameraUsageDescription = "This app needs camera access to take photos of inspections and site documents.";`
- Use `PHPickerViewController` for Photo Library (no photo-library usage string). `UIImagePickerController` for camera. `UIDocumentPickerViewController` with `UTType.jpeg`, `UTType.png`, `UTType.pdf`.

**Interfaces:**
- Consumes: `SiteRacking`, `SiteDocumentFile`, `Catalog.names`, `Catalog.add`, `UserManager.shared.sessionUserId`, `Customer.maxSiteDocumentBytes`, `Customer.allowedContentTypes`, `Customer.maxSiteDocumentCount`
- Produces:

```swift
final class SiteRackingViewController: UIViewController {
    init(
        siteRacking: SiteRacking,
        siteDocuments: [SiteDocumentFile],
        context: NSManagedObjectContext = CoreDataManager.shared.context,
        onDone: @escaping (SiteRacking, [SiteDocumentFile]) -> Void
    )
}
```

Copy inputs into private vars. Nav: Cancel (dismiss without callback), Done (if `siteRacking.validationMessage()` != nil, `UIAlertController` with that string; else `onDone` then dismiss). Title `"Site racking"`.

Scroll + stack:
1. Header `"Site documents"`. Horizontal stack of tiles (UIImage if jpeg/png else PDF icon + filename). Add button disabled at 5. Action sheet: Camera, Photo Library, Files. After pick: if `data.count > Customer.maxSiteDocumentBytes`, alert `"Each file must be 10 MB or smaller."` and skip. Camera: `jpegData(compressionQuality: 0.8)`, filename `site-photo.jpg`, type `public.jpeg`. PNG/PDF from picker keep bytes and filename.
2. Three sections Uprights / Beams / Decks. `UISegmentedControl` Standardized | Mixed. On Mixed→Standardized: if `!canSet*Standardized()` ignore the change and reset segment (no delete). Mixed shows Add row button. Each row: manufacturer `UIButton` presenting a table of `Catalog.names(kind: .manufacturer, userId:session, in:context)` plus “Add manufacturer…” alert; then text fields. Deck: type dropdown via `CatalogKind.deckType`. Empty manufacturer rows are allowed on screen; validation runs on Done.

Permissions: camera via `AVCaptureDevice.requestAccess` when Camera is chosen; denied → alert with Settings URL. PHPicker does not need library permission.

No new UITests.

- [ ] **Step 1: There is no meaningful unit test for the VC.** Guardrail: `SiteRacking.validationMessage()` already tested. Build the target after adding the VC.

- [ ] **Step 2: Implement `SiteRackingViewController.swift`** using AppTheme, 16pt stack spacing, 44pt fields, matching `CustomerFormViewController`.

- [ ] **Step 3: Build** (`xcodebuild build -scheme "Systems Inspector" -destination "platform=iOS Simulator,name=iPhone 16"`) — succeed

- [ ] **Step 4: Commit** (skip unless asked)

---

### Task 7: Hosts (form + details)

**Files:**
- Modify: `Systems Inspector/CustomerFormViewController.swift`
- Modify: `Systems Inspector/CustomerDetailsViewController.swift`

**Interfaces:**
- Consumes: `SiteRackingViewController`, `CustomerFormState.siteRacking`, `siteDocuments`, `CustomerIntake`
- Produces: form button + details summary + persist paths from the spec

**Form:** After zip field in the stack, add section header `"Site"` and a `UIButton` title `"Site racking & documents"`. Subtitle `UILabel` under it:

```swift
func siteRackingSubtitle(form: CustomerFormState) -> String {
    if form.siteRacking.isEmpty && form.siteDocuments.isEmpty { return "Not set" }
    let mfr = form.siteRacking.uprights.rows.first?.manufacturer
        ?? form.siteRacking.beams.rows.first?.manufacturer
        ?? form.siteRacking.decks.rows.first?.manufacturer
    let docs = form.siteDocuments.count
    if let mfr, docs > 0 { return "\(docs) documents · \(mfr)" }
    if let mfr { return mfr }
    if docs == 1 { return "1 document" }
    if docs > 1 { return "\(docs) documents" }
    return "Configured"
}
```

Button action: `navigationController?.pushViewController(SiteRackingViewController(siteRacking: form.siteRacking, siteDocuments: form.siteDocuments) { [weak self] racking, docs in self?.form.siteRacking = racking; self?.form.siteDocuments = docs; self?.updateSiteRackingSubtitle() }, animated: true)`.

`pullFieldsIntoForm` / `applyFormToFields` must not assign empty spec/docs. Save path already uses `form` after `validatedForm()` which pulls text fields only — keep spec/docs on `form` across that pull.

**Details:** In `setupCustomerInfoHeader`, after zip (before Added), add a tappable summary control (button) using the same subtitle helper on `CustomerIntake.formState(from: customer)`. Tap: present `UINavigationController(rootViewController: SiteRackingViewController(...))` as large sheet with grabber (copy Edit Customer presentation). `onDone`:

```swift
var form = CustomerIntake.formState(from: customer)
form.siteRacking = racking
form.siteDocuments = docs
_ = CustomerIntake.update(customer, form: form)
```

Then refresh header subtitle. Cancel: no Intake.

After Edit Customer saves, header already reloads via delegate — include the new summary in that rebuild.

- [ ] **Step 1: No new unit tests.** Existing CustomerIntakeTests cover persist.

- [ ] **Step 2: Wire form + details as above**

- [ ] **Step 3: Run** `CustomerFormStateTests`, `CustomerIntakeTests`, `SiteRackingTests`, `CatalogTests`, `CustomerSiteDocumentTests` — all PASS. Build the app scheme.

- [ ] **Step 4: Manual check** (simulator): Add Customer → Site racking sheet → add Interlake upright+beam, one PDF, Done, Save; open Details and confirm summary; Edit name only and confirm PDF still there.

- [ ] **Step 5: Commit** (skip unless asked)

```
git add -A
git commit -m "feat(customer): optional SiteRacking profile and SiteDocuments"
```

---

## Spec coverage

| Spec item | Task |
|-----------|------|
| SiteRacking JSON + pair/row rules + mixed switch | 1 |
| Customer.siteRackingJSON, SiteDocument, CatalogName | 2 |
| Manufacturer/DeckType seed + add + user scope | 3 |
| documentFiles / replaceDocuments, cap 5, keep-by-id | 4 |
| FormState + Intake hydrate/create/update | 5 |
| Sheet UI, pickers, 10 MB, permissions | 6 |
| Form push + Details sheet + subtitle | 7 |
| Web codec / Report unchanged | (no task — do not touch) |
| CONTEXT.md terms | already in repo from design phase |
