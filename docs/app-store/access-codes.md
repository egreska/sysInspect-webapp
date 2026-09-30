# Access Codes

How to issue and retire an Access Code for Pallet Rack Safety. The iOS app does not enforce this yet. Create the schema and the review code before the build that contains the gate is submitted. App Store and TestFlight builds read the **Production** database.

Container: `iCloud.SysInspectDB`. Database: **public**. The private database holds inspections and must not hold codes.

## Record type

Create record type `AccessCode` in Development, then deploy the schema to Production.

| Field | Type | Purpose |
| --- | --- | --- |
| Record name | the code itself | The string you send to the inspector. Not a separate field. |
| `status` | String | `issued`, `claimed`, or `retired` |
| `claimedUserRecordName` | String | CloudKit user record name of the Inspector. Empty until claimed. |
| `claimedAt` | Date/Time | When the Claim was written. |
| `retiredAt` | Date/Time | When the code was Retired. |

Security, on the Development schema before you deploy:

- `_world`: no permissions. A person who is not signed into iCloud cannot read codes.
- Signed-in iCloud users: Read and Write, so the app can fetch one record and write the Claim. Leave Query off if the role editor has it.
- The app fetches by record name only. It does not run a query that returns every Access Code.

Deploy schema changes to Production before creating the records you will send to inspectors.

## Issue a code

1. Open [CloudKit Dashboard](https://icloud.developer.apple.com), container `iCloud.SysInspectDB`.
2. Data → **Production** → public database → `AccessCode`.
3. Generate a code and use it as the record name:

```bash
openssl rand -hex 16
```

4. Set `status` to `issued`. Leave `claimedUserRecordName`, `claimedAt`, and `retiredAt` empty.
5. Save the record, then send the record name to that inspector. One code, one Inspector.

A string that is not a record name is not an Access Code. The first Apple ID to claim an `issued` record becomes the Inspector. A different Apple ID is refused. The same Apple ID on another device is the same Inspector.

## Retire a code

1. Open that record in **Production**.
2. Set `status` to `retired` and `retiredAt` to now.
3. Leave `claimedUserRecordName` in place. Do not delete the record.

A deleted record looks the same as a code that was never issued, and a phone that already claimed it cannot learn that the seat ended. A Retired code cannot be Claimed again. The next Inspector gets a new record.

The phone keeps working until it can reach CloudKit. The next successful check locks the app. Inspections stay on the device and in that Apple ID’s iCloud.

## Review code

Create one Production record with `status` `issued` for the submission. Put that record name in the review notes. The reviewer’s Apple ID claims it, then creates the one Session in the app.

Leave that code Claimed while that Apple ID still needs to open the app. A later review on a different Apple ID needs a new `issued` code. Retire the review code when you are done with it, the same way you retire an inspector’s code.
