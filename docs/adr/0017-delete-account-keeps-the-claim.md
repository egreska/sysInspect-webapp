# Delete Account keeps the Claim

Delete Account removes the Session and the inspection records that belong to it, including their iCloud copies. It does not Retire the Access Code. The same Apple ID can create a new Session. A different Apple ID still cannot use that code.

**Considered options:** Treat Clear All Data as deletion. Tell review there is no account to delete. Retire the code when the Session is deleted.

**Consequences:** `sessionReady` is cleared only after iCloud has accepted the deletions. Until then the gate does not offer Create Account, including after the app is opened again. Retiring stays a dashboard action. Logout only ends the Session and leaves the records.
