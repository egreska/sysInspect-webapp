# Multiple Photos per Inspection Item Implementation Plan

> **Status:** Shipped. The checkboxes below are not a live tracker.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (inline) or superpowers:subagent-driven-development. Steps use checkbox syntax for tracking.

**Goal:** Let an inspection item store up to five photos, added one at a time, shown on iOS, PDF/ZIP reports, and the web dashboard.

**Architecture:** Five packed slots on `InspectionItem` (`photoData`/`photoURL` plus 2…5). `InspectionItemIntake.PhotoListChange` writes the list. A shared photo strip UI adds/removes. Reports keep photo 1 in the table and extras under the row. Web decodes five CloudKit asset fields into `photoUrls`.

**Tech Stack:** UIKit, Core Data + CloudKit, Swift tests, React/TypeScript/Vitest.

**Spec:** `docs/superpowers/specs/2026-08-27-multi-photo-inspection-item-design.md`

## Global Constraints

- Max 5 photos per item, packed left
- Add one at a time from the form camera/library picker
- Individual remove; `.unchanged` must not rewrite JPEGs
- JPEG quality 0.8
- No new CloudKit record type

---

### Task 1: Slots + helper + intake

**Files:** Core Data model; `InspectionItem+PhotoExtension.swift`; `InspectionItemIntake.swift`; `InspectionItemIntakeTests.swift`; `CoreDataManager.swift`

**Produces:** `InspectionItem.maxPhotoCount`, `photoCount`, `hasPhoto`, `photoData(at:)`, `photoURLString(at:)`, `setPackedPhotos`, `getPhoto(at:)`, `getAllPhotosSync()`, `clearPhotoCache()`. Draft `photos: PhotoListChange` (`.unchanged` | `.set([UIImage])`).

- [ ] Add photoData2…5 and photoURL2…5
- [ ] Tests: slot 1, five photos, compact remove, cap, unchanged, empty set clears
- [ ] Implement helper + intake + migrate all slots

### Task 2: iOS UI

**Files:** `InspectionPhotoStripView.swift`; `InspectionFormViewController.swift`; `CustomerDetailsViewController.swift` (detail, edit, list)

**Consumes:** helper + `PhotoListChange`

- [ ] Strip + preview; camera adds until 5; per-thumb remove
- [ ] Detail shows all photos; list shows count when > 1

### Task 3: Reports

**Files:** `ReportGenerator.swift`; `ReportExportTests.swift`

- [ ] Photo 1 in table; extras under row; ZIP `_1`…`_N`

### Task 4: Web

**Files:** `types/index.ts`; `inspectionItemCodec.ts` + tests; detail/preview pages; `pdfGenerator.ts`

- [ ] `photoUrls: string[]`; decode five fields; gallery + PDF extras
