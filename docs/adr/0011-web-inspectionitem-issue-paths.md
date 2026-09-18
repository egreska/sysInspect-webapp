# Web InspectionItem carries Issue Paths, not Flag bools

Web load yields InspectionItem with recorded Issues as Paths. CloudKit `CD_*` bools and Flag maps stay in the codec. Display uses `Issue.labels` from those Paths, matching iOS. We considered keeping Flag fields on the load entity and unifying the three page/PDF projectors. That leaves CloudKit shape on the load interface and lets labels diverge again.

**Considered options:** Flag bools on InspectionItem; Paths on InspectionItem, Flags in the codec (chosen).

**Consequences:** Pages and PDF do not read Flag fields. Codec tests assert Paths from `CD_` records. Load tests use Path fixtures. Do not put `CD_` or Flag maps on `createLoad` (see ADR-0009).
