# Customer SiteRacking and SiteDocuments

Date: 2026-09-01

## Problem

A Customer today is name, site string, contact, and address. Inspectors have nowhere to keep warehouse blueprints/rack layouts or the installed rack mix (manufacturer, upright/beam/deck specs). That profile belongs on the Customer (one Customer = one warehouse), not on each Inspection, and must not be confused with InspectionItem Issues (upright/beam/deck damage).

## Goals

- Optional **SiteDocuments** on Customer: photos and/or PDFs, at most five, for blueprints and rack layouts.
- Optional **SiteRacking** on Customer: Uprights, Beams, Decks; each type Standardized (one spec) or Mixed (several).
- Manufacturer and DeckType catalogs for this Session user, seeded, add-only, shared across that user’s Customers.
- iOS Add/Edit Customer and Customer Details can open one “Site racking” sheet (documents + spec).
- Persist through `CustomerFormState` / `CustomerIntake`. Callers ask for document bytes and filename, not slots.

## Non-goals

- Printing SiteRacking or SiteDocuments on PDF/CSV Report this pass
- Web UI for spec or files (web Customer decoder must keep working; extra CloudKit fields ignored)
- New Site entity or multiple warehouses per Customer
- Pre-filling InspectionItems; copying the profile onto Inspection
- Reusing Issue paths for catalog/spec data
- Manufacturer/DeckType rename or delete
- CAD/DWG and unlabeled “any file” types
- Document category labels (blueprint vs rack layout)
- Company-wide or app-wide catalogs (public CloudKit)

## Approach

Hybrid:

- SiteRacking: one optional JSON `Data` attribute on Customer
- SiteDocument: to-many entity (bytes, filename, content type), cap 5 in Intake
- Manufacturer / DeckType: one `CatalogName` entity (`kind` + `name` + `userId`)

## Data model

### Customer

Add optional `siteRackingJSON` (`Binary` / `Data`, **not** external storage). `nil` means no profile.

Do **not** add `documentData1…5` on Customer.

### SiteDocument (new, CloudKit syncable)

| Attribute | Type |
|-----------|------|
| `id` | UUID |
| `filename` | String |
| `contentType` | String (`public.jpeg`, `public.png`, `public.pdf`) |
| `data` | Binary, `allowsExternalBinaryDataStorage=YES` |
| `userId` | UUID |
| `sortIndex` | Integer 32 |
| `customer` | to-one Customer (Customer `siteDocuments` to-many, cascade delete) |

### CatalogName (new, CloudKit syncable)

| Attribute | Type |
|-----------|------|
| `id` | UUID |
| `kind` | String (`manufacturer` or `deckType`) |
| `name` | String |
| `userId` | UUID |

No unique constraint (CloudKit). De-dupe is case-insensitive trim in the catalog module, scoped by `userId` + `kind`.

### SiteRacking JSON

Value type `SiteRacking` encodes this blob. Empty profile ↔ `nil` on Customer (not `{}`).

```
{
  "uprights": { "mode": "standardized" | "mixed", "rows": [ UprightRow ] },
  "beams":    { "mode": "standardized" | "mixed", "rows": [ BeamRow ] },
  "decks":    { "mode": "standardized" | "mixed", "rows": [ DeckRow ] }
}
```

- UprightRow: `manufacturer` (required if row is recorded), `height`, `depth`, `color` (optional strings)
- BeamRow: `manufacturer`, `length`, `color`
- DeckRow: `manufacturer`, `type` (DeckType name, required if recorded), `size`

A type is **recorded** when it has ≥1 row with a non-empty manufacturer. Standardized + zero recorded rows = not recorded. Default mode is `standardized`.

**Pair rule:** if Uprights are recorded, Beams must be, and vice versa. Decks are optional. Empty SiteRacking is valid. Decks-only is valid.

**Row rules:** recorded row needs manufacturer; recorded deck row also needs type. Height/depth/length/color/size may be empty. `CustomerFormState.isValid` stays name-only.

**Mixed → Standardized:** allowed only when that type’s `rows.count <= 1`. Standardized → Mixed keeps the existing row and allows Add.

## Catalog

Module (not UserManager, not the sheet talking to Core Data ad hoc):

- `names(kind:userId:)` — if none exist for that user+kind, insert seed, then return sorted names
- `add(name:kind:userId:)` — trim; reject blank; reject case-insensitive duplicate; insert

Manufacturer seed: Interlake, Ridg-U-Rak, Mecalux, Steel King, UNARCO, Hannibal, Speedrack, Frazier, Teardrop (generic).

DeckType seed: wire, particle, bar grate, other.

First sheet open can show seeds. Add is an alert text field on the dropdown.

## Intake API

`CustomerFormState` includes `siteRacking: SiteRacking` (empty default) and `siteDocuments: [SiteDocumentFile]`.

```
struct SiteDocumentFile {
  var id: UUID?          // existing SiteDocument; nil = new
  var filename: String
  var contentType: String
  var data: Data         // required for new files; unused on keep
}
```

- Create/update: write `siteRackingJSON` from `SiteRacking` (nil if nothing recorded).
- Documents: keep entities whose `id` is still in the array (**do not rewrite `data`**); insert nil-id files (require `data`); delete missing ids; cap **5** (drop extras); stamp `userId` / `sortIndex`.
- Hydrate: decode JSON (missing/invalid blob → empty SiteRacking); map SiteDocuments by `sortIndex` into `SiteDocumentFile` **with `id` and `data`** (preview and later Save need the bytes in form state). Keep-by-id still ignores draft `data`.
- Name-only edits must not recreate CloudKit assets for unchanged files. Contact fields on the form must not clear `siteRacking` / `siteDocuments` (those live on the struct, not text fields).

Customer screens call `documentFiles()` / Intake, not `data` attributes or relationship internals.

## iOS UI

One `SiteRackingViewController`. Edits a **copy** of `siteRacking` + `siteDocuments`. Reads/adds CatalogName only. Title “Site racking”. Cancel discards the copy. Done runs pair + row rules; failure stays with an alert; success returns the copy via completion.

Scroll stack, AppTheme, 44pt fields:

1. **Site documents** — up to five tiles (image thumbnail or PDF icon + filename). Add → action sheet Camera / Photo Library / Files. Accept JPEG, PNG, PDF only. Each file ≤ **10 MB** at pick time. Tap → `QLPreviewController`. Remove per tile. Add disabled at 5.
2. **Uprights, Beams, Decks** — always visible. Segmented Standardized | Mixed (default Standardized). One row when standardized; Mixed shows Add. Mixed → Standardized disabled while `rows.count > 1`. Row card: manufacturer table + “Add manufacturer…”. Optional free-text size/color fields. Deck type uses the same dropdown pattern as manufacturer.

Camera JPEG at the same compression as inspection photos (80%). Library/Files keep PNG or PDF bytes as picked.

### Hosts

- **CustomerFormViewController:** button after Address, “Site racking & documents”, subtitle “Not set” or e.g. “3 documents · Interlake”. **Push** on the form’s nav stack. Completion writes form state only. Customer Save still calls `CustomerIntake`.
- **CustomerDetailsViewController:** same summary in the header. Tap presents this VC in a large nav sheet (same presentation as Edit Customer). Done: hydrate form from Customer, apply copy, `CustomerIntake.update`. Cancel does not write.

## Errors and permissions

- Camera/library permission when that Add action is chosen, not at launch. Denied → alert with Open Settings.
- Pair/row failures: one specific alert, no persist.
- Duplicate/blank catalog add: no extra row (duplicate may alert).
- Save/Core Data failure: existing “Could not save customer” alert.
- Over 10 MB or wrong type: alert, file not added.

## Web and Report

No web UI this pass. `customerCodec` keeps current fields; unknown CloudKit keys stay ignored.

ReportSnapshot Customer fields stay id, name, site, address.

## Tests

In-memory Core Data, same pattern as `CustomerIntakeTests`.

- SiteRacking JSON round-trip; empty ↔ nil blob; standardized vs mixed counts
- Pair/row: uprights-only invalid; beams-only invalid; empty valid; decks-only valid; deck without type invalid
- `canSetStandardized` false when `rows.count > 1`
- Intake create/update/hydrate spec + documents; 6th file dropped; keep-by-id does not require rewriting bytes for name-only update
- Catalog: seed once; second fetch no duplicate seed; add de-dupes case-insensitively; scoped by `userId`
- `CustomerFormState.isValid` ignores spec/docs
- Existing web/customer decode tests still pass (no codec change required)

No new UITests for the sheet this pass.

## Files (expected)

- `Systems_Inspector.xcdatamodeld` — `siteRackingJSON`, `SiteDocument`, `CatalogName`
- `SiteRacking.swift` — value types, JSON, pair/row rules, `canSetStandardized`
- `SiteDocument+Files.swift` (or equivalent on Customer) — bytes/filename API
- Catalog module — seed, list, add
- `CustomerFormState.swift`, `CustomerIntake.swift`
- `SiteRackingViewController.swift`
- `CustomerFormViewController.swift`, `CustomerDetailsViewController.swift`
- Tests: `SiteRackingTests.swift`, catalog tests, extend `CustomerIntakeTests` / `CustomerFormStateTests`

Language: [CONTEXT.md](../../../CONTEXT.md) (`SiteRacking`, `SiteDocument`, `Manufacturer`, `DeckType`).
