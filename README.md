# Systems Inspector

iOS inspection management app: customers, inspections, photos, PDF reports, Core Data + CloudKit. Optional Firebase Analytics/Crashlytics.

## Requirements

- **Xcode** 16+ (see `Podfile` / CocoaPods notes for Xcode 26 + Pods)
- **iOS** 14.0+
- **CocoaPods** (for Firebase)

## Quick start

```bash
cd "/path/to/Systems Inspector"
pod install
open "Systems Inspector.xcworkspace"
```

Build with **⌘B**, run with **⌘R**. Use the **`.xcworkspace`** when CocoaPods is installed.

## Tech stack

Swift, UIKit, Core Data, CloudKit, Combine. Firebase via CocoaPods (optional).

## Documentation

| Topic | File |
|--------|------|
| Index | [DOCUMENTATION.md](DOCUMENTATION.md) |
| User manual | [USER_GUIDE.md](USER_GUIDE.md) |
| Firebase | [FIREBASE_SETUP_GUIDE.md](FIREBASE_SETUP_GUIDE.md) |
| In-app help copy | [HELP_AND_SUPPORT_CONTENT.md](HELP_AND_SUPPORT_CONTENT.md) |
| Web app | [webapp/README.md](webapp/README.md) |
| Planning / ideas | [docs/planning.md](docs/planning.md) |

## Tests

```bash
./scripts/run_tests.sh   # optional; requires tooling
```

In Xcode: **Product → Test** (**⌘U**).

## Configuration (examples)

Tunable values live in source (not exhaustive):

- **Account lockout:** `AccountLockoutManager.swift` — attempt count, lockout duration  
- **Image cache:** `ImageCacheManager.swift` — memory/disk limits  
- **Customer list page size:** `CustomerDirectoryViewModel.swift` — `pageSize`

## Troubleshooting

- **Build errors after pods:** `pod install`, open **`.xcworkspace`**, **Clean Build Folder**, rebuild.  
- **Firebase:** see [FIREBASE_SETUP_GUIDE.md](FIREBASE_SETUP_GUIDE.md).  
- **Pods / Xcode 26:** maintain project via **Podfile** + `pod install`; avoid manually “updating recommended settings” on **Pods** unless you know the impact.

---

*See [DOCUMENTATION.md](DOCUMENTATION.md) for the full map.*
