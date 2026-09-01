# Systems Inspector — User Guide

**Version:** 1.0 · **Updated:** March 2026

## Contents

1. [Getting started](#getting-started)  
2. [Account](#account)  
3. [Customers & inspections](#customers--inspections)  
4. [Photos & reports](#photos--reports)  
5. [Search & navigation](#search--navigation)  
6. [Settings](#settings)  
7. [Performance & cache](#performance--cache)  
8. [Security & privacy](#security--privacy)  
9. [Troubleshooting](#troubleshooting)  
10. [FAQ & support](#faq--support)

---

## Getting started

Systems Inspector helps you manage field inspections: customers, inspection records, photos, and PDF reports, with **CloudKit** sync when iCloud is available.

**Highlights**

- Local-first data with optional iCloud sync  
- PDF reports from inspection data  
- Image caching for responsiveness  

### First launch

1. **Create account** — email, password, security question (for password reset).  
2. **Inspector profile** — **Settings → Inspector Settings**: name (used on reports), company, contact (optional).  
3. Explore **Customers**, open a customer, then **New Inspection** as needed.

### Password rules

- At least **8** characters  
- **1** uppercase, **1** lowercase, **1** digit  

Passwords are stored with strong hashing; the app never shows your raw password after save.

### Security questions

Pick a question you can answer consistently. The answer is used only for **Forgot Password** on this device flow (see app behavior for exact steps).

---

## Account

### Create account

**Create New Account** → email, password, security Q&A → submit. Use a real email you control if you rely on export or support.

### Log in

Email + password. If enabled, **Face ID / Touch ID** can unlock after first successful login (see **Settings**).

### Forgot password

From the login screen: **Forgot Password** → verify email → answer security question → set a new password that meets the rules above.

### Account lockout

Repeated failed logins trigger a **temporary lockout** (see in-app messaging for attempt counts and duration). Waiting out the timer or completing a valid **password reset** clears the lockout path.

### Change password

Use the in-app flow from **Settings** (or account security section) when logged in. Old password is required where the app specifies.

---

## Customers & inspections

### Customers

- **Add:** Customers tab → **+** → fill name, company, contact → **Save**.  
- **Find:** Search bar filters by name, company, email, phone as implemented.  
- **Edit / delete:** From the customer row or detail screen per UI affordances (swipe, **Edit**, etc.).  
- Large directories may load in **pages** (e.g. batches of 20) — scroll to load more.

### Inspections

1. Open a **customer**.  
2. **New Inspection** (or equivalent).  
3. Set **date**, **location**, and other fields your form shows.  
4. Add **damage / component** rows: type, severity, notes.  
5. Attach **photos** where needed.  
6. **Save** — data persists locally and syncs via CloudKit when possible.

### Damage components

Use the guided picker for component and damage types to keep reports consistent. Required fields are enforced before save where the app marks them.

---

## Photos & reports

### Photos

- Capture with the **camera** or choose from the **library** per permissions.  
- Images are associated with inspection items; you can remove or replace per screen controls.  
- Thumbnails and full images use **caching** — first load may be slower; revisiting is faster.

### PDF reports

From the inspection or report flow, generate a **PDF** with criteria you select (date range, layout options, etc., per current app screens). Share via the system sheet (**Mail**, **Files**, **AirDrop**, …).

If generation fails, see [Troubleshooting](#troubleshooting).

---

## Search & navigation

- **Global / customer search** — type in the search field; results narrow as you type.  
- **Tabs** — primary areas (e.g. Customers, Reports, Settings) per your build’s `MainTabBarController`.  
- **Back** — use navigation bar **Back** to preserve unsaved state warnings where implemented.

---

## Settings

Typical areas (names may match your build):

- **Inspector / profile** — name, company, contact for reports.  
- **Appearance / theme** — if offered.  
- **Biometrics** — enable quick unlock.  
- **Help & Support** — short topics and links to this guide.  
- **Data** — export / reset options if present; destructive actions usually need confirmation.

---

## Performance & cache

The app uses **memory and disk caches** for images to keep scrolling smooth.

- **First-time** loads or **large** libraries may take a moment.  
- **Clear cache** (if exposed in Settings) frees space; images may reload from storage or cloud.  
- **Low storage** on device can slow photo writes — free space if saves fail.

---

## Security & privacy

- Data is **encrypted at rest** on device per iOS Data Protection; **CloudKit** sync uses Apple’s infrastructure under your Apple ID / iCloud settings.  
- **Analytics / crash reporting** (if Firebase is enabled) should be described in your privacy policy and App Store disclosures.  
- **Backups** — device backups include app data per your iTunes / Finder / iCloud Backup settings.

---

## Troubleshooting

| Problem | Things to try |
|--------|----------------|
| Cannot log in | Check caps lock, use **Forgot Password** if needed; wait out lockout or reset. |
| Sync delays | Check network; confirm iCloud signed in and **iCloud Drive** / CloudKit allowed for the app; force-quit and reopen after network returns. |
| Photos missing | Confirm **Photos** permission in **Settings → Privacy**; retake or reattach. |
| PDF fails | Retry after closing other heavy apps; ensure inspection has minimum required fields; update iOS if the share sheet misbehaves. |
| Crash on launch | Update the app; reinstall only if you have a backup/export strategy — see support. |

---

## FAQ & support

**Is my data only in the cloud?**  
No — Core Data holds a local store; CloudKit syncs when available.

**Can I use the app offline?**  
Many actions work offline; sync catches up when online.

**How do I export data?**  
Use **Settings** export options if present; PDFs export via the share sheet.

**Who do I contact?**  
Use **Help & Support** → **Contact** (or the email shown in-app) for product support.

---

*For developers: Firebase setup, web app, and doc index — see **README.md** and **DOCUMENTATION.md**.*
