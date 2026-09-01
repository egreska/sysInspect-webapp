# Help & Support Content (in-app copy)

Formatted for **Settings → Help & Support**. Full detail: **USER_GUIDE.md**.

---

## Section 1: Getting Started

### Title: "Welcome to Systems Inspector"
**Content:**
```
Systems Inspector helps you manage inspections: customers, inspections, photos, and PDF reports. Data syncs with iCloud (CloudKit) when you’re signed in.

See the User Guide in Settings for the full manual.
```

---

## Section 2: Account & Login

### Topic: "Creating an Account"
**Content:**
```
1. Tap Create New Account
2. Enter email and password
3. Choose a security question and answer
4. Submit

Password: 8+ characters, 1 upper, 1 lower, 1 number. Passwords are hashed; we don’t store plain text.
```

### Topic: "Logging In"
**Content:**
```
Email + password. You can enable Face ID or Touch ID in Settings after a successful login for faster unlock.

Too many wrong attempts may temporarily lock the account — the screen shows what to do next (wait or use Forgot Password).
```

### Topic: "Forgot Your Password?"
**Content:**
```
Forgot Password → enter email → answer your security question → set a new password.

If you can’t answer the question, you may need account recovery help through support.
```

### Topic: "Account Lockout"
**Content:**
```
Failed logins can trigger a short lockout to reduce guessing attacks. Wait for the timer, or use Forgot Password if you’re the real account owner.
```

---

## Section 3: Using the App

### Topic: "Managing Customers"
**Content:**
```
Customers tab: add (+), search, open a customer for details. Edit or delete from the list or detail screen. Long lists may load in pages — scroll to load more.
```

### Topic: "Creating Inspections"
**Content:**
```
Open a customer → New Inspection → date, location, damage rows, notes, photos → Save. You can add multiple components and photos per inspection.
```

### Topic: "Adding Photos"
**Content:**
```
Add Photo → camera or photo library (grant permissions in Settings if prompted). First load may use the network; revisiting the same image is faster thanks to caching.
```

### Topic: "Generating Reports"
**Content:**
```
From the inspection or reports flow, generate a PDF, then share via Mail, Files, AirDrop, or other apps. Ensure photos have finished loading if they should appear in the PDF.
```

---

## Section 4: Performance

### Topic: "Why is the app responsive?"
**Content:**
```
Images use memory and disk caching. Customer lists may use pagination so large directories stay scrollable. Heavy work runs off the main thread where possible.
```

### Topic: "Performance & cache"
**Content:**
```
If Settings exposes Performance or cache controls, you can inspect memory/cache usage or clear the image cache. Clearing cache frees space; images may download again.
```

### Topic: "Cache management"
**Content:**
```
Clear Image Cache removes cached thumbnails/files. Use when troubleshooting storage or stale images — not needed for normal daily use.
```

---

## Section 5: Settings

### Topic: "Inspector settings"
**Content:**
```
Set the name and company that appear on PDFs. Enable biometrics for quicker login. iCloud must be available for CloudKit sync.
```

### Topic: "Data management"
**Content:**
```
Clear cache: only image cache, data reloads as needed.

Clear All Data: destructive — requires confirmation and usually your password. Export PDFs first if you need records offline.
```

---

## Section 6: Security

### Topic: "How is my data protected?"
**Content:**
```
Passwords are hashed with a strong KDF. Data is stored using iOS protections; CloudKit sync uses Apple’s infrastructure. Enable biometric login only on devices you trust.
```

### Topic: "Privacy"
**Content:**
```
We don’t sell your inspection data. Content lives on your devices and in your iCloud account when sync is on. Review the App Store privacy details for analytics/crash reporting if enabled.
```

---

## Section 7: Troubleshooting

### Topic: "Can't log in"
**Content:**
```
Check spelling and caps. Use Forgot Password. If locked out, follow the on-screen timer or reset flow. Re-enable Face ID/Touch ID in Settings if biometrics fail.
```

### Topic: "Sync issues"
**Content:**
```
Confirm network and iCloud sign-in. Toggle airplane mode off, reopen the app, or restart the device if CloudKit is stuck. First-time photo loads need connectivity.
```

### Topic: "Performance issues"
**Content:**
```
Close other apps, free storage, restart the app or device. Clear image cache if Settings offers it and you’re troubleshooting slowness.
```

### Topic: "Photo issues"
**Content:**
```
Check Photos and Camera permissions. Retry after network returns. Clear image cache only if images look wrong or storage is tight.
```

### Topic: "PDF issues"
**Content:**
```
Retry after photos load. Free disk space. Try sharing to Files first if the share sheet misbehaves.
```

---

## Section 8: Quick Tips

### Topic: "Tips"
**Content:**
```
Use Wi‑Fi for large syncs when possible. Keep iOS updated. Back up your device if you rely on local data.
```

---

## Section 9: Common Questions

### Topic: "Frequently Asked Questions"
**Content:**
```
Q: Work offline?
A: Core features work offline; sync resumes when online.

Q: Multiple devices?
A: Same Apple ID / iCloud setup can sync via CloudKit.

Q: Delete the app?
A: Cloud data may remain in iCloud; local data is removed with the app. Plan exports before deleting.

Q: Report a bug?
A: Use App Store feedback or the contact option in Settings if shown.
```

---

## Section 10: App Information

### Topic: "About Systems Inspector"
**Content:**
```
See Settings → About (if present) for version and build. Requires iOS 14 or later unless your release notes say otherwise.
```

### Topic: "Contact & Support"
**Content:**
```
Read the User Guide, then contact support through the email or link shown in Settings, or leave structured feedback on the App Store.
```

---

## Section 11: Quick Reference

### Topic: "Feature summary"
**Content:**
```
Customers, inspections, photos, PDF reports, search, settings, optional biometrics, CloudKit sync when iCloud is available.
```

---

*Developer wiring notes: **HELP_IMPLEMENTATION_GUIDE.md**.*
