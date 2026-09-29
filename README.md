# Systems Inspector

iOS inspection management app: customers, inspections, photos, PDF reports, Core Data + CloudKit. Optional Firebase Analytics/Crashlytics.

## Requirements

- **Xcode** 26.2+
- **iOS** 15.0+
- **Swift Package Manager** (Firebase Analytics and Crashlytics, pinned in the Xcode project)

## Quick start

```bash
cd "/path/to/Systems Inspector"
open "Systems Inspector.xcodeproj"
```

Xcode resolves the Firebase package on open. Build with **⌘B**, run with **⌘R**.

## Tech stack

Swift, UIKit, Core Data, CloudKit, Combine. Firebase via Swift Package Manager.

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

- **Build errors:** open **`.xcodeproj`**, **File → Packages → Reset Package Caches** if Firebase fails to resolve, then **Clean Build Folder** and rebuild.
- **Firebase:** see [FIREBASE_SETUP_GUIDE.md](FIREBASE_SETUP_GUIDE.md).

---

*See [DOCUMENTATION.md](DOCUMENTATION.md) for the full map.*
