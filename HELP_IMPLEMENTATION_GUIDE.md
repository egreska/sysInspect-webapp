# Help & Support — developer notes

The iOS product name in user-facing help is **Pallet Rack Safety**. This repository and the Xcode project stay **Systems Inspector**.

## Where the text lives

- [USER_GUIDE.md](USER_GUIDE.md) is the long manual. The app does not load this file.
- [HELP_AND_SUPPORT_CONTENT.md](HELP_AND_SUPPORT_CONTENT.md) is the short copy for the four Help screens.
- `HelpContentViewController` hardcodes that same short copy. There is no markdown loader.

When you change help text, update **both** `HELP_AND_SUPPORT_CONTENT.md` and the matching string in `HelpContentViewController`. The four screens are User Guide, FAQ, Troubleshooting, and About.

`SettingsViewController` has its own About screen and Privacy Policy. Those are not read from the markdown files. Update them in Swift when the product description or privacy claims change.

## Entry point

`SettingsViewController.showHelpAndSupport()` pushes `HelpAndSupportTableViewController`. That table pushes `HelpContentViewController` for each row. It does not call `SettingsActionsDelegate`.

## Editing rules

- Use Issue, Importance, site racking, and site document. Do not write “damage component.”
- Importance values are **Needs immediate attention** and **Monitor**.
- Describe only behavior that is in the app. Restore Data is one sentence: it is not available in this version.
- Support email in the guides is support@skynet97.org. Bug reports go to bugs@skynet97.org.
- Password length and lockout numbers must match `PasswordRecoveryManager` and `AccountLockoutManager` (8 characters with upper, lower, and a number; 5 failures; 15 minutes).
