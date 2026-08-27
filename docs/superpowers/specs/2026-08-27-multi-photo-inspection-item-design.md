# Multiple photos per inspection item

Date: 2026-08-27

## Problem

An inspection item can store only one photo (`photoData` / `photoURL`). Inspectors need extra angles of the same damage. That single photo is used on the iOS form, item edit, customer item list, PDF/ZIP reports, CloudKit, and the web dashboard — so extras must show in all of those places.

## Goals

- Add photos one at a time from the item form (camera/library picker as today). A new shot does not replace existing ones.
- At most **five** photos per item.
- Remove any individual photo; remaining photos stay and compact left.
- Show every photo everywhere the current photo already appears: iOS form, item detail/edit, PDF/ZIP reports, web dashboard.

## Non-goals

- Burst / stay-in-camera multi-shot session
- More than five photos, or a related Photo entity
- Drag-to-reorder, captions, or a “remove all” control
- Changing JPEG compression (stay at 80%)

## Data model

Keep `photoData` / `photoURL` as slot 1 on `InspectionItem`. Add:

- `photoData2` … `photoData5` — Binary, optional, external storage (same as slot 1)
- `photoURL2` … `photoURL5` — String, optional (local file path, same as slot 1)

Empty slots are `nil`. Photos are always packed left: three photos occupy slots 1–3, never 1, 2, and 5.

Existing items with one photo need no migration. Slot 1 is already populated.

All read/write of photos goes through a helper on `InspectionItem` (`photoCount`, `photo(at:)`, `allPhotos()`, `hasPhoto` meaning any slot is set). Other code does not touch `photoData3` directly.

CloudKit continues to use `CD_InspectionItem`. Extra binaries sync as additional asset fields on the same record (`CD_photoData2`, …). No new record type.

## Intake API

`InspectionItemDraft` no longer uses a single-photo `PhotoChange` of replace/remove.

```
enum PhotoListChange {
  case unchanged
  case set([UIImage])  // 0...5 images, packed; empty array clears all slots
}
```

- Field-only edits pass `.unchanged` so existing JPEGs are not re-encoded or re-uploaded to CloudKit.
- Any add or remove on the form passes `.set(currentThumbnails)`.
- Intake writes the array into slots 1…N and clears leftover slots in one Core Data save.
- A sixth image is not accepted (UI hides the camera at five; intake ignores extras if it ever receives more than five).

If JPEG encoding fails for a new shot, that image is not added and the form shows an error. Other photos are unchanged.

## iOS UI

**Add-item and edit-item forms**

Replace the single thumbnail + “Retake” with:

- A horizontal row of up to five thumbnails
- The existing camera button, which adds the next photo and returns to the form
- A remove control on each thumbnail (remaining photos slide left; camera returns if the count was five)
- Tap thumbnail → full-screen preview

Camera button is visible for 0–4 photos and hidden at 5. Same `UIImagePicker` (camera/library) as today.

The in-memory thumbnail list is what intake writes on save.

**Customer item list rows**

Keep one thumbnail (photo 1). If `photoCount > 1`, show a count badge on that thumbnail. Opening the item shows the full strip.

**Accessibility**

VoiceOver: “Photo 2 of 4” on each thumbnail, matching “Remove photo 2 of 4” on the remove control.

## Reports

PDF table layout is unchanged for one-photo items: the photo column shows **photo 1** at the current size.

Additional photos (2–5) draw in a strip under that item’s row, aspect-fit. If they don’t fit on the page, the extra strip moves to the next page with the item (not orphaned).

ZIP export attaches every photo, named so they stay tied to the item (`…_1.jpg` … `…_N.jpg`). CSV stays text-only.

The web PDF uses the same rule.

## Web dashboard

Replace `photoUrl` / `photoData` on the TypeScript `InspectionItem` with `photoUrls: string[]` (empty if none). Update every caller.

The CloudKit decoder reads up to five asset fields on `CD_InspectionItem` (`CD_photoData_ckAsset` / `CD_photoData` / `CD_photoURL`, then `CD_photoData2`, …). A legacy single-photo record becomes a one-element array. No extra CloudKit queries.

- Inspection detail: horizontal gallery, tappable to enlarge
- List/summary: first photo + count badge when there are extras
- Report preview: first photo in the table, extras under the row

Display skips empty or unloadable slots; a missing asset does not hide the others.

## Files (expected)

iOS: Core Data model, `InspectionItem+PhotoExtension.swift`, `InspectionItemIntake.swift`, `InspectionFormViewController.swift`, `CustomerDetailsViewController.swift`, `ReportGenerator.swift`, `CoreDataManager.swift` (local→CloudKit photo migrate over all slots), `InspectionItemIntakeTests.swift`, report export tests.

Web: `types/index.ts`, `inspectionItemCodec.ts` + tests, `InspectionDetailPage.tsx`, `ReportPreviewPage.tsx`, `pdfGenerator.ts`.

## Tests

- One photo still lands in slot 1
- Adding up to five fills 1…N and clears leftover slots
- Removing a middle photo compact-writes
- More than five images are not stored
- `.unchanged` does not clear or rewrite existing slots
- Empty `.set([])` clears all slots (same as today’s remove)
- Decoder: zero, one, and several CloudKit asset fields → `photoUrls`
- PDF/ZIP include every attached file, named `_1`…`_N`
