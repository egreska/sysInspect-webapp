# Claims are public CloudKit records

A Claim is stored in the public database of `iCloud.SysInspectDB`. It does not live in a server we run, and it does not live in the private database that holds inspections. The company creates the Access Code record before sending it. The first Claim binds it to that iCloud user record. A Retired code cannot be Claimed again. Issuing and retiring happen in the CloudKit Dashboard.

**Considered options:** A license server with Sign in with Apple; a first-come string with no pre-issued record; public CloudKit records (chosen). Reusing a Retired code for the next Inspector.

**Consequences:** App Store and TestFlight builds read the Production database. Unclaimed codes are fetched by record name and are not queryable, so a client cannot list every issued code. A modified client can skip the check. After a successful check, inspections keep working offline until the app next reaches CloudKit and sees a Retired code. The inspector web app cannot issue codes. The next Inspector receives a newly issued code.
