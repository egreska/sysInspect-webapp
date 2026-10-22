# An Inspector is an Apple ID with one Session

The Inspector is the Apple ID that claimed the Access Code. The same Apple ID on another device is the same Inspector. A different Apple ID is a different Inspector. Whoever has the code can take the Claim, including after it is bound. An Inspector has one Session, the email and password login. Inspections follow the Apple ID through iCloud sync. The code does not move the inspections.

**Considered options:** Bind the code to the Session email; bind it to one device; bind it to the Apple ID (chosen). Allow several Sessions on one Apple ID.

**Consequences:** There is no Inspector to bind until iCloud is signed in. A second device waits for the existing Session to sync and does not offer a new email. There is no Session before the Claim. Retiring the code locks the app and leaves inspections with that Inspector.
