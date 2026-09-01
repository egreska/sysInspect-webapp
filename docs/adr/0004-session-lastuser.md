# Session is the logged-in id; LastUser is a separate id for Face ID

Session is the logged-in user’s id, owned by UserManager. Callers may read it; only UserManager writes it. LastUser is the user id of the last account that held a Session, also owned by UserManager, used for Face ID after logout. We considered keeping email and an `isLoggedIn` flag as Session, or leaving Face ID on session email so logout could not clear Session honestly. That tangles “am I logged in?” with “who was here last.” Logged in means a Session id is present. Logout keeps LastUser; login and account create replace it; wipe clears both through UserManager.

**Considered options:** Face ID reads Session email (logout cannot clear Session); LastUser as email; Session id passed into Intake instead of read from UserManager; LastUser as a separate id on UserManager (chosen).

**Consequences:** Do not store session email or an `isLoggedIn` bool. Do not treat LastUser as logged in. Screens do not read UserDefaults Session or LastUser keys. Wipe calls UserManager, not a blanket key delete, to end Session. Tests inject UserDefaults rather than writing `sessionUserId`.
