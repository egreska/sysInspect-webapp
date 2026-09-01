# Snapshots at the Report export seam, not Inspection entities

Report produces a PDF or CSV package from grouped inspection snapshots (customer identity and site, date, InspectionItem rows with Issue paths and photo bytes). Callers and tests learn that value type, not the Core Data graph. A mapper outside Report is the production adapter from entities. We considered keeping `[Inspection]` on `export` and testing through an in-memory store. That leaves Core Data on the interface: every Report change still pays the entity tax, and the join rule stays coupled to `objectID`. Snapshots make join identity customer id + site, keep Issue label/sort rules inside Report via `Issue.Path`, and let export tests construct rows by hand.

**Considered options:** keep `Inspection` entities at export (in-memory store in tests); snapshots at the seam (chosen).

**Consequences:** Report does not import Core Data. Do not add `export([Inspection])` beside snapshot export. Combined PDF join is enforced on snapshots; the screen may call `canJoin` to skip the layout sheet. Missing ZIP companion still does not fail CSV (see ADR-0002).
