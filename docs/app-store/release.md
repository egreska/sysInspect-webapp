# App Store release — Pallet Rack Safety

Copy for App Store Connect, and the order to submit it. Decisions are in [0014](../adr/0014-unlisted-access-code.md), [0015](../adr/0015-inspector-is-apple-id.md), and [0016](../adr/0016-claims-in-cloudkit-public-db.md). Issuing codes is in [access-codes.md](./access-codes.md).

The Access Code gate is **not in version 0.7.1**. Do not submit this listing, and do not send the review notes below, until that gate is in the binary you upload. The notes tell the reviewer to enter a code. A build that ignores the code would make those notes false.

Before you submit:

1. Deploy the web app so these URLs load without signing in:
   - Privacy: `https://sysinspect.skynet97.org/privacy`
   - Support: `https://sysinspect.skynet97.org/support`
2. Deploy the `AccessCode` schema to CloudKit **Production** and create the review code.
3. Archive a Release build that enforces the gate. Marketing version in the project is `0.7.1`, build `1.0`.

## Order in App Store Connect

Apple will not make the first version unlisted by itself. The first submission is a **public**, **free** app. The Account Holder then asks Apple to switch it to unlisted. A private Apple Business Manager app cannot be switched to unlisted. That path needs a new app record.

1. App Store Connect → Apps → New App. Platform iOS. Name **Pallet Rack Safety**. Bundle ID `EKGDev.Systems-Inspector`. SKU `pallet-rack-safety`.
2. Pricing and Availability: price **Free**. No in-app purchases. Availability **all territories**. Distribution method **Public**.
3. Fill in the version page with the fields below. Upload screenshots. Answer the age rating and the privacy questions.
4. In Review Notes, say the app is intended for unlisted distribution, and include the review code.
5. Submit for review. The binary must be a final release, not a beta. Apple declines the unlisted request if the app has not been submitted, or if it is still a prerelease.
6. After the submission exists, the **Account Holder** submits [Request unlisted app distribution](https://developer.apple.com/contact/request/unlisted-app/). Background on the program: [Unlisted App Distribution](https://developer.apple.com/support/unlisted-app-distribution).
7. When Apple approves the request, Pricing and Availability changes to **Unlisted**. The direct link is on that page. Future versions stay unlisted. Test the link. A shortened link has to resolve to it.

Anyone with the link can install. The Access Code is what entitles one Apple ID.

## Listing fields

| Field | Value |
| --- | --- |
| Name | Pallet Rack Safety |
| Subtitle | Warehouse rack inspections |
| Primary category | Business |
| Secondary category | leave empty |
| Content rights | This app does not contain third-party content |
| Copyright | 2026 EKGDev |
| Support URL | https://sysinspect.skynet97.org/support |
| Marketing URL | leave empty |
| Privacy Policy URL | https://sysinspect.skynet97.org/privacy |
| Price | Free |
| Availability | All territories |

The Xcode category key is still `public.app-category.utilities`. The category shoppers would have used is the Business value on this page. The About screen in the app still says “© 2025 EKG Apps”. The listing copyright is 2026 EKGDev.

**Promotional text** (170 characters):

```
Record rack inspections in the field: locations, photos, and PDF or CSV reports. Install from the direct link. An issued access code entitles one Apple ID.
```

**Description:**

```
Pallet Rack Safety is for field inspections of storage-rack systems.

Record a customer and the site, walk the racks, and note each location. Mark whether a location needs immediate attention or should be monitored. Attach photos and the site's racking profile. Generate a PDF or CSV report and share it from the device.

Inspections stay on the device. When iCloud sync is on, they sync to that Apple ID. A report goes to the people you send it to.

The app is free and is not sold as a public download. An inspector installs it from the direct link. Use requires an access code issued for one Apple ID.
```

**Keywords** (100 characters, the app name is already indexed):

```
racking,inspection,warehouse,audit,report,storage,bay,upright,beam
```

**What’s New** for this version:

```
First App Store release.
```

## Screenshots

The target is iPhone and iPad, so Connect requires both. Use the sizes the upload page marks required. For a new app those are usually:

- iPhone 6.9-inch: 1320 × 2868
- iPad 13-inch: 2064 × 2752

Capture at least the customer list, an inspection location with a photo, and a report preview. Use a Release-like build with sample data that contains no real customer.

## Age rating

Answer **None** or **No** for every content question: violence, sexual content, profanity, horror, gambling, contests, unrestricted web access, and user-generated content shared in a social network. Reports are shared by the inspector through the share sheet.

This produces **4+**. Do not select Made for Kids.

## App privacy

Data is not used to track the inspector. There is no tracking prompt.

Declare the following. Inspection contents are included because iCloud sync puts them in CloudKit, and the developer account can open that container in the dashboard. Firebase events do not include customer names, photos, or report files.

| Data | Linked to the user | Purpose |
| --- | --- | --- |
| Email address | Yes | App functionality |
| Name, address, and phone the inspector types for a customer or for report letterhead | Yes | App functionality |
| Photos | Yes | App functionality |
| User ID (the account id sent to Firebase) | Yes | Analytics |
| Product interaction (screen views and feature events) | Yes | Analytics |
| Crash data | Yes | App functionality |
| Other diagnostic data (Crashlytics) | Yes | App functionality |

Not collected: precise location, contacts from the address book, health, financial info, browsing history, advertising data.

Camera use is described in the binary: photos of inspections and site documents. Face ID is used to unlock the app and is not sent off the device.

## Export compliance

`ITSAppUsesNonExemptEncryption` is `NO` on the app target. The app uses HTTPS, CloudKit, and password hashing provided by the system. On upload, if Connect still asks: the app uses encryption, and it qualifies for the exemption for encryption built into the operating system.

## Review notes

Paste this with the gated build. Replace the code with the Production record name from [access-codes.md](./access-codes.md).

```
This app is intended for unlisted distribution. It is free. It should not appear in search, categories, charts, or recommendations. Please approve it for the public store so we can request the unlisted link.

Sign in to iCloud on this device before opening the app. Enter this Access Code:

[PRODUCTION RECORD NAME]

The code is an AccessCode record in the Production public database of iCloud.SysInspectDB. Entering it binds the code to the Apple ID on this device. Then create the one account with any email and a password you choose.

There is no sample inspection. Create a customer, add a location, take or attach a photo, and generate a PDF.

A different Apple ID must not be able to use the same code. Signing out of iCloud leaves no Inspector on the device.

Support: support@skynet97.org
```

Sign-in information: required. There is no password to attach. The reviewer creates the Session after the code. Put a phone number Connect will accept in the review contact fields. The notes do not include one.

## After approval

Send inspectors the unlisted link and one Access Code each. Retire a code from the CloudKit Dashboard when that Inspector should lose access. The next Inspector gets a new code.
