# Planning and improvements (condensed)

This file replaces separate roadmap / quick-wins / iOS suggestion docs. Use it as a backlog sketch, not a contract.

## iOS app (themes)

From earlier review notes, useful directions include:

- **Reliability:** meaningful errors for CloudKit/sync; avoid blocking the main thread on Core Data notifications.
- **UX:** consistent navigation, accessibility (VoiceOver, Dynamic Type), clear empty states.
- **Data:** validate migrations; document backup/restore expectations with iCloud.
- **Quality:** keep tests aligned with real flows; run before release.

## Web app

The **React + CloudKit JS** frontend is documented under [webapp/README.md](../webapp/README.md) and [webapp/docs/](../webapp/docs/). A historical code-review snapshot lives in [webapp.md](webapp.md).

Older “roadmap to 10” and “quick wins” docs assumed a **Node backend** with Zod/Winston/etc. That stack is not part of the current frontend-only Docker path; treat those as **optional** if you reintroduce an API server.

## Priorities (flexible)

1. Ship and monitor (Crashlytics, user feedback).  
2. Harden sync and offline edge cases.  
3. Expand tests around critical paths.  
4. Web/iOS parity only where product requires it.
