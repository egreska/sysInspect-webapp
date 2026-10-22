# The Security Answer travels with the Session

The Security Answer used to stay on the phone that set it. A second phone on the same Apple ID received the Session and still could not reset the password. The answer now sits on that Session's user record, with the question text, the hash, and the salt. The phone copies a leftover local answer once, the next time it has the Session, then drops the local copy. Wrong guesses still lock only the phone that made them. There is no server.

**Considered options:** Leave the answer on this phone. Add a server to store it.

**Consequences:** Another phone can reset once the Session record has arrived. A phone that is never opened again keeps its answer. If two phones save different answers, the later save wins. A hash with no salt is copied as it is and still upgrades on the next correct answer. Delete Account removes the answer with the Session.
