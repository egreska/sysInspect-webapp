# Firebase (Analytics & Crashlytics)

Short reference for **Systems Inspector** iOS. Firebase is wired through Swift Package Manager; this doc covers console setup, plist, build phases, and verification.

## 1. Firebase project

1. Open [Firebase Console](https://console.firebase.google.com/) → **Add project** (enable Google Analytics if you want dashboards).
2. **Add app** → **iOS** → bundle ID matches Xcode (**Target → General → Bundle Identifier**), e.g. `EKGDev.Systems-Inspector`.
3. Download **GoogleService-Info.plist**. Never commit this file — it contains `API_KEY` and related client identifiers. The repo ignores it via `.gitignore`.

## 2. Swift Package Manager

The app target depends on **firebase-ios-sdk** `12.18.0` (exact) from `https://github.com/firebase/firebase-ios-sdk.git`. Linked products are **FirebaseCore**, **FirebaseAnalytics**, and **FirebaseCrashlytics**. The app target sets **Other Linker Flags** to `-ObjC` so Analytics categories are not stripped.

Open **`Systems Inspector.xcodeproj`**. Xcode resolves packages into Derived Data. The lockfile is `Systems Inspector.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`.

## 3. Local `GoogleService-Info.plist` (do not commit)

1. Copy the tracked template:
   ```bash
   cp GoogleService-Info.plist.example GoogleService-Info.plist
   ```
2. Replace it with the real file downloaded from Firebase Console (same path at the repo root), or fill in the placeholder values from the console.
3. Confirm Xcode still references **`GoogleService-Info.plist`** (not the `.example` file):
   - File is in the project navigator and listed under **Copy Bundle Resources**.
   - Target Membership is enabled for the app target.
4. Only `GoogleService-Info.plist.example` is safe to commit. The real `GoogleService-Info.plist` must stay local and untracked.

## 4. App bootstrap

`AppDelegate` should call `FirebaseApp.configure()` early in `application(_:didFinishLaunchingWithOptions:)`. `AnalyticsManager` uses **FirebaseAnalytics** and **FirebaseCrashlytics** — keep imports and event calls aligned with your privacy policy.

## 5. Crashlytics build phase

1. Target **Systems Inspector** → **Build Phases** → **+** → **New Run Script Phase** (often named **Firebase Crashlytics**).
2. Script:

```bash
"${BUILD_DIR%/Build/*}/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/run"
```

3. **Input Files** include the dSYM paths, the built executable, and:

```
$(TARGET_BUILD_DIR)/$(UNLOCALIZED_RESOURCES_FOLDER_PATH)/GoogleService-Info.plist
```

4. **Debug Information Format**: **DWARF with dSYM File** (already set for Debug and Release). Keep this phase last.

## 6. Privacy & App Store

- **Info.plist**: camera / photo library usage strings if you access those APIs.
- **App Store privacy labels** and in-app privacy text should mention analytics/crash data if you collect them.
- If you offer an opt-out, wire it to `AnalyticsManager` / Firebase APIs consistently.

## 7. Verify

- Run the app, perform a few flows; check Xcode console for analytics logging if enabled.
- Firebase Console → **Analytics** (events may be delayed) and **Crashlytics** (after a test crash in a dev build, symbolicated builds need matching dSYMs).

## 8. Troubleshooting

| Issue | What to try |
|--------|-------------|
| Package resolve or build fails | Open **.xcodeproj**, reset package caches, clean the build folder, and rebuild. Confirm the pin is firebase-ios-sdk 12.18.0. |
| Missing plist at build time | Ensure `GoogleService-Info.plist` exists locally (copy from `.example` then replace with the Firebase download). Do not retarget the app at the example file. |
| No crashes in Crashlytics | Confirm run script, dSYM settings, and that you’re looking at the correct Firebase app / bundle ID. |
| Wrong Firebase project | Replace the local plist with the one for the correct iOS app registration. Do not commit it. |

For web deployment and CloudKit (not Firebase), see **webapp/docs/** in the repo.
