# Knowing the code is the Claim

Signed-in iCloud users can write an Access Code record in the public database. The app will not replace an owner. CloudKit cannot limit that write to the moment the code is issued. The code is a 128-bit value, so anyone who can overwrite a Claim could have claimed it first.

Write stays. The phone still writes the Claim, `sessionReady`, and the clear after Delete Account. There is no server.

**Considered options:** Remove Write and make the dashboard the only writer. Add a server to write the Claim.

**Consequences:** Whoever has the code holds the Claim, including after it is bound. Retire still makes the app stop on the next check. Someone who has the code can write the record again. This refines ADR 0015, which had said a different Apple ID is not the Inspector even with the code. That remains what the app shows. It is not what the database enforces.
