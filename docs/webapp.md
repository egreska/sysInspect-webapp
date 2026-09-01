# Web app — review snapshot

**Date:** 2026-02-06  
**Note:** Summarizes an older full-stack review (React + Node API). The repo’s **current** web stack is **frontend + CloudKit JS** (see [webapp/README.md](../webapp/README.md)).

## Themes addressed historically

| Area | Direction |
|------|-----------|
| Auth / API | Constant-time password compare, no stack traces to clients, strong `JWT_SECRET` in production |
| HTTP clients | Timeouts on outbound requests |
| Client | Safe `localStorage` access, avoid 401 redirect loops |

## Current docs

- [webapp/docs/DEPLOYMENT.md](../webapp/docs/DEPLOYMENT.md) — deploy (e.g. Coolify)  
- [webapp/docs/CLOUDKIT_SETUP.md](../webapp/docs/CLOUDKIT_SETUP.md) — CloudKit JS + tokens  
- [webapp/docs/SECURITY.md](../webapp/docs/SECURITY.md) — headers, tokens, incident response  

There is **no** separate `API.md` in this tree; the live app talks to **CloudKit** from the browser per **CLOUDKIT_SETUP.md**.
