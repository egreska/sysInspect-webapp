# Firebase (Analytics & Crashlytics)

Short reference for **Systems Inspector** iOS. Firebase is wired through CocoaPods; this doc covers console setup, plist, build phases, and verification.

## 1. Firebase project

1. Open [Firebase Console](https://console.firebase.google.com/) → **Add project** (enable Google Analytics if you want dashboards).
2. **Add app** → **iOS** → bundle ID matches Xcode (**Target → General → Bundle Identifier**), e.g. `com.yourcompany.systemsinspector`.
3. Download **GoogleService-Info.plist** (keep it private; do not commit secrets to public repos if policy forbids it).

## 2. CocoaPods

```bash
cd "/path/to/Systems Inspector"
pod install
```

Open **`Systems Inspector.xcworkspace`** (not `.xcodeproj`) after pods are installed.

## 3. Add `GoogleService-Info.plist`

1. Drag **GoogleService-Info.plist** into the Xcode project navigator.
2. Enable **Copy items if needed** and the **Systems Inspector** target.
3. In File Inspector, confirm **Target Membership** for the app target.

## 4. App bootstrap

`AppDelegate` should call `FirebaseApp.configure()` early in `application(_:didFinishLaunchingWithOptions:)`. `AnalyticsManager` uses **FirebaseAnalytics** and **FirebaseCrashlytics** — keep imports and event calls aligned with your privacy policy.

## 5. Crashlytics build phase

1. Target **Systems Inspector** → **Build Phases** → **+** → **New Run Script Phase** (often named **Firebase Crashlytics**).
2. Script:

```bash
"${PODS_ROOT}/FirebaseCrashlytics/run"
```

3. **Debug Information Format**: **DWARF with dSYM File** for Release (and Debug if you upload symbols from Debug builds).
4. Optional: add the Crashlytics **Input Files** paths recommended in Firebase’s current docs for dSYM upload reliability.

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
| Build fails after `pod install` | Clean build folder, use **.xcworkspace**, run `pod install` again. |
| No crashes in Crashlytics | Confirm run script, dSYM settings, and that you’re looking at the correct Firebase app / bundle ID. |
| Wrong Firebase project | Replace plist with the one for the correct iOS app registration. |

For web deployment and CloudKit (not Firebase), see **webapp/docs/** in the repo.
