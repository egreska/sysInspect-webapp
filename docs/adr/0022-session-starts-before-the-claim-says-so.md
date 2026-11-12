# A Session starts before the Claim says so

Starting a Session saves the user and the Keychain secret, then tries to mark the Claim session-ready. If that mark does not finish, the Session stays. The screen says this iPad could not update the Claim yet. A logged-in Inspector still resolves to the main app. A later access check retries the mark. Rolling the Session back would throw away a password that is already on this phone. Holding the Inspector on waiting for the Session would treat a logged-in phone like one that has no Session yet.

**Considered options:** roll back the user and the secret until the Claim is session-ready; keep the Session and block on waiting for the Session; keep the Session, say so, and enter the app (chosen).

**Consequences:** Do not roll back a started Session when the mark fails. Do not send that Inspector to waiting for the Session. The create screen does not call the mark itself. Logout and Delete Account stay out of this path. `changePassword` stays outside it.
