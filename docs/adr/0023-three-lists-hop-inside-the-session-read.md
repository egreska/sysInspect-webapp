# Three lists hop inside the session read

The customer page, the inspection list, and the item list pass the view context and the Session's user id. The read still runs on a background context, and the object-id copy stays inside. Callers get objects on the view context they passed. The directory asks for a page index. The page size and the total stay inside. Search, both row counts, deep links, and Spotlight keep calling the read on the context they already hold. The Reports tab stays out. Recorded order stays out. The read still does not touch UserManager.

A missing store, or a customer or inspection that cannot be resolved on the background context, throws. Each screen keeps its own words and its loading flags.

**Considered options:** leave the hop on the screens; fold every caller, including search, counts, and the Reports tab; sort items inside the read; have the module read the Session. None of those. The three lists hop inside (chosen).

**Consequences:** Do not pass a background context from these three screens. Do not hop search, the counts, deep links, or Spotlight. Do not sort InspectionItems here. Do not add the Reports tab. Predicate tests stay on the direct read. Hop tests pass a view context.
