# Help & Support — developer notes

**Purpose:** `HELP_AND_SUPPORT_CONTENT.md` holds copy formatted for **Settings → Help & Support**. `USER_GUIDE.md` is the longer manual.

## Integration

- **UI:** `HelpAndSupportTableViewController` presents the help surface; entry from `SettingsViewController` (`showHelpAndSupport()`).
- **Content:** Prefer loading strings from a small struct or localized resources that mirror the sections in `HELP_AND_SUPPORT_CONTENT.md`, or render Markdown in a `UITextView` / `WKWebView` if you expand the UI.

## Editing workflow

1. Update **USER_GUIDE.md** for full documentation.
2. Mirror short, user-facing snippets into **HELP_AND_SUPPORT_CONTENT.md** so in-app text stays consistent.
3. Avoid duplicating password rules and lockout numbers in three places — change **AccountLockoutManager** / product copy together.

## Optional enhancements

Search, categories, and deep links are product decisions; keep the table-driven structure in `HelpAndSupportTableViewController` unless you need richer navigation.
