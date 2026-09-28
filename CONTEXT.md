# Systems Inspector

Field inspections of storage-rack systems: customers, inspections, and the issues recorded on each inspection item.

## Language

**InspectionItem**:
A single location on an Inspection (bay/position) where conditions are recorded. Callers ask for photo bytes, not storage slots or file URLs. At most five photos. Callers ask for recorded Issues as Paths, not Flag maps or Core Data bools.
_Avoid_: line item, finding, row, mapper photos, photoDataList, photoURL, packed photo tuples, issueFlagMap, applyIssueFlags

**Issue**:
A condition from a fixed hierarchy (parent, optional child, optional grandchild), recorded on an InspectionItem as a Path. Display labels come from those Paths; a leaf is listed only when its parent is recorded.
_Avoid_: damage, finding, defect, DamageComponent, Flag map

**Report**:
An exported PDF or CSV of one or more Inspections. Callers pick Inspections; ReportFromInspections turns that selection into Report. Report itself takes snapshots, not entities.
_Avoid_: export, package, document, ReportViewController hop

**Importance**:
How urgently an InspectionItem needs attention: Needs immediate attention, or Monitor. Critical means Needs immediate attention; a missing value, Repair, Urgent, or any other word means Monitor.
_Avoid_: Critical, Repair, Urgent, priority, severity

**InspectionItemIntake**:
The iOS module at the seam between InspectionItemFormState and InspectionItem, in both directions (create, update, hydrate).
_Avoid_: mapper, codec, DamageComponent factory, draft, InspectionItemDraft

**InspectionItemFormState**:
The in-memory form for one InspectionItem (location, Importance, issues, photos) before InspectionItemIntake persists it. Create and edit present one InspectionItemFormViewController; that screen owns chrome and Intake. InspectionFormViewModel owns inspection lifecycle only.
_Avoid_: ViewModel, mapper, draft, InspectionFormViewController, InspectionItemEditViewController

**CustomerFormState**:
The in-memory form for one Customer (name, site, contact, address, SiteRacking, SiteDocuments) before CustomerIntake persists it.
_Avoid_: ViewModel, mapper, Add/Edit form

**SiteRacking**:
Optional installed-equipment profile on a Customer: Site Information, Load Information, Upright Frames, Beams, Wire Decks, Cross Bars, Safety Clips, Anchors, and Row Spacers. Hardware types (except Site Information, Load Information, and Safety Clips) are standardized (one spec that names a manufacturer) or mixed (several), a spec with no manufacturer name does not count, and the profile is not an Issue or an Inspection.
_Avoid_: inventory, rack layout, Issue, Inspection snapshot, DamageComponent

**SiteDocument**:
An optional photo or PDF on a Customer. At most five. Callers ask for bytes and filename, not storage slots or file URLs.
_Avoid_: attachment, blueprint entity, Customer photo, packed document tuples

**Manufacturer**:
A catalog name owned by this Session user, chosen on Upright Frames, Beams, Cross Bars, Anchors, and Row Spacers. Shared across that user's Customers, not across inspectors. Not the Wire Decks manufacturer list.
_Avoid_: brand, vendor, company-wide catalog

**WireDeckManufacturer**:
A catalog name for wire-deck makers (Nashville Wire, J&L Wire, ITC, Worldwide, Little Giant (Brennan), Hallowell, Husky, Interlake Mecalux, Steel King, Ridg-U-Rak, plus user additions), owned by this Session user.
_Avoid_: Manufacturer catalog, brand, vendor

**DeckType**:
A catalog name for deck construction (Upturned WF, Inside WF, Flat Flush, Inverted Flare, Inverted U-Channel, Standard U-Channel, Flared Channel, Welded Wire Decking, plus user additions), owned by this Session user.
_Avoid_: wireDeck Issue flag, deck material enum in Issues

**CustomerIntake**:
The iOS module at the seam between CustomerFormState and Customer, in both directions (create, update, hydrate).
_Avoid_: mapper, AddCustomerViewController, EditCustomerViewController

**Session**:
The logged-in user's id on iOS, owned by UserManager. Entity `userId` attributes are data stamped from session, not session itself. Password writes (create, change, reset) go through UserManager. Screens do not read `currentUserEmail` or `isLoggedIn`. Wipe uses verify-without-login, not `authenticateUser`. Wipe ends Session through UserManager.
_Avoid_: CoreDataManager.currentUserID, PasswordRecoveryManager hashing, duplicate PBKDF2, UserDefaults Session keys outside UserManager, LastUser

**LastUser**:
The user id of the last account that held a Session on this device, used for Face ID after logout. Not logged in; not Session.
_Avoid_: currentUserEmail, session email, remembered login, Face ID as Session
