# Paths at the InspectionItem Issue seam, not Flag maps

InspectionItem persist and read for Issues is `replaceIssues` and `recordedIssues` (Paths). Flag KVC and Core Data bools stay in the implementation. Display labels come from those Paths. We considered keeping `issueFlagMap` / `applyIssueFlags` public, or routing Report and CustomerDetails through Intake. That leaves Flag wiring on every caller and pulls FormState into Report. Paths on InspectionItem match photo bytes (ADR-0005). We considered keeping Flag display overloads beside persist conversion; Path-only display matches the persist seam.

**Considered options:** Flag map on InspectionItem; Paths only through Intake; Paths on InspectionItem (chosen). Flag display overloads; Path-only `labels` / `primaryParentLabel` (chosen).

**Consequences:** Do not expose `issueFlagMap` / `applyIssueFlags`. Product code and Intake tests assert Paths. Issue still converts Flag ↔ Path for persist. Display takes Paths, not Flag maps.
