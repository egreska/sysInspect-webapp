# Web load sits in front of CloudKit and in-memory adapters

Pages load Customer, Inspection, and InspectionItem through `createLoad`. Join, sort, and missing-id throws live in that module. CloudKit JS plus codecs are one adapter; an in-memory map is the other. We considered deleting `api.ts` and leaving joins in `cloudkitApi`. That keeps `CD_` and REFERENCE filters on the load interface, and tests stop at codecs. Two adapters make the seam real. Lists keep `customerId` only; `inspectionById` attaches Customer and items. InspectionItem carries `inspectionId` so joins are not Core Data REFERENCES.

**Considered options:** in-process collapse of `api.ts` into `cloudkitApi`; adapters that each implement full load; `createLoad` with entity-yielding adapters (chosen).

**Consequences:** Do not import `queryRecords` / `CD_` from pages. Do not keep a pass-through `customersAPI`. Codec tests stay on the CloudKit adapter. Load tests use the in-memory adapter.
