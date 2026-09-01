# Selected Inspections reach Report through ReportFromInspections

The Report screen picks rows and format. ReportFromInspections applies empty-selection (PDF: first row; CSV: all), hops to a background context, maps snapshots, and calls snapshot `export`. Report still takes snapshots, not `Inspection` entities (ADR-0003). We considered `export([Inspection])` on ReportGenerator, or growing the mapper into the orchestrator. Either reopens ADR-0003 or makes mapping own hop and selection. `canJoin` takes the same Selection (PDF-first, photos off) so the screen can skip the layout sheet without mapping. Tests cover the selection rule; hop is not injected; snapshot `export` tests stay at Report.

**Considered options:** `export([Inspection])` on ReportGenerator; grow ReportSnapshotMapper; ReportFromInspections in front of Report (chosen).

**Consequences:** Do not hop or map on ReportViewController. Do not add `export([Inspection])`. Screen keeps pick, one `canJoin` to skip the PDF sheet, share, and the two empty-list alert strings. Join is still enforced inside `export`. Header, sort, date-range, and layout stay gathered on the screen.
