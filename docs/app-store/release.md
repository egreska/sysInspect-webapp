# App Store release — Pallet Rack Safety

Copy for App Store Connect, and the order to submit it. Decisions are in [0014](../adr/0014-unlisted-access-code.md), [0015](../adr/0015-inspector-is-apple-id.md), and [0016](../adr/0016-claims-in-cloudkit-public-db.md). Issuing codes is in [access-codes.md](./access-codes.md).

The app enforces the Access Code gate. Deploy the `AccessCode` schema and create the review code in the CloudKit database that build uses before you submit. Xcode reads Development. TestFlight and the App Store read Production.

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

Paste this into Resolution Center and into App Review Information on the next submission. Attach the screen recording from the shot list below. The Production code is `cf6b58a0503cb0f634c45bf74047689d`.

```
This app is intended for unlisted distribution. It is free. It should not appear in search, categories, charts, or recommendations. Please approve it for the public store so we can request the unlisted link.

Purpose and audience
Pallet Rack Safety is a field tool for people who inspect warehouse storage racks. The inspector records a customer and site, walks the racks, notes each location, attaches photos, and produces a PDF or CSV report. It replaces collecting that inspection on paper and reassembling it later. The inspection stays with that inspector and can be sent as a report. It is for warehouse and safety inspectors who receive an access code from the company that issued the app. It is not a public consumer product.

How to reach the main features
A screen recording from a physical device, running the latest iOS, is attached. It starts at launch.

1. Sign in to iCloud on the device before opening the app.
2. Enter this Access Code:

cf6b58a0503cb0f634c45bf74047689d

The code is an AccessCode record in the Production public database of iCloud.SysInspectDB. Entering it binds the code to the Apple ID on this device.
3. Create the one account with any email and a password you choose. There is no preset password and no sample file.
4. Create a customer, add a location, take or attach a photo, and generate a PDF.
5. Settings → Delete Account. Confirm with the password you just created. This removes that account and its inspections from the device and from iCloud. The same Apple ID can create a new account with this access code. A different Apple ID cannot use this code.

Account registration, login, and deletion
The recording shows Create Account, login, and Delete Account. Delete Account is in Settings. It requires the account password and a final confirmation. It removes the account and the customers, inspections, photos, and site documents that belong to it.

User-generated content
Inspections, photos, and notes are private to the signed-in Apple ID. There is no social feed, no sharing between inspectors, and no public profile. A report leaves the device only when the inspector uses the system share sheet. Content reporting and blocking do not apply.

Paid content
The app is free. There are no in-app purchases, subscriptions, or paid features. The access code is issued outside the app. It is not an Apple offer code.

External services
- Apple iCloud and CloudKit, container iCloud.SysInspectDB. This is core functionality. Inspections sync in the private database. Access-code claims are stored in the public database.
- Firebase Analytics and Firebase Crashlytics. Diagnostics only. Events do not include customer names, photos, or report files.
The app does not use a payment processor, a map provider, or an AI service.

Regions
The app functions the same in every territory where it is available. There are no regional differences in features or content.

Regulated industry and third-party material
The app records the inspector’s own observations. It does not certify a rack, does not provide engineering approval, and does not include standards text or other protected third-party material. No authorization documents are required.

Signing out of iCloud leaves no Inspector on the device.

Support: support@skynet97.org
```

Sign-in information: required. There is no password to attach. The reviewer creates the Session after the code. Put a phone number Connect will accept in the review contact fields. The notes do not include one.

### Screen recording

Record this on a physical iPhone or iPad running the latest iOS, in one take. Start before tapping the icon. The device is already signed in to the Apple ID that holds `cf6b58a0503cb0f634c45bf74047689d`, and it has a network connection. Delete Account updates the access code record, so it cannot finish offline.

1. Launch Pallet Rack Safety from the home screen.
2. Enter the access code and continue.
3. Create an account. Use any email, a password, and a security question.
4. Add a customer.
5. Add one inspection location, attach a photo, and save it.
6. Generate a PDF, open the share sheet, and dismiss it without sending.
7. Open Settings, tap Delete Account, confirm, enter the password, and confirm again.
8. Show the app back at account creation for the same Apple ID.

Do not show another person’s content, a purchase, or a real customer.

## After approval

Send inspectors the unlisted link and one Access Code each. Retire a code from the CloudKit Dashboard when that Inspector should lose access. The next Inspector gets a new code.
