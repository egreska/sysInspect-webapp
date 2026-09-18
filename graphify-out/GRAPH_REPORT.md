# Graph Report - Systems Inspector  (2026-09-17)

## Corpus Check
- 69 files · ~177,806 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 4 file(s) not represented in the graph (top: (none) 2, .storyboard 1, .entitlements 1)

## Summary
- 1459 nodes · 3389 edges · 66 communities (57 shown, 9 thin omitted)
- Extraction: 95% EXTRACTED · 5% INFERRED · 0% AMBIGUOUS · INFERRED: 164 edges (avg confidence: 0.82)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- Report Dates And PDF
- Filter Preset Storage
- Image Cache Manager
- Account Creation Screen
- Customer Form State
- Account Lockout Manager
- Customer Details Screen
- Analytics Event Logging
- PDF Table Layout
- Filter Chips Photo Strip
- Site Racking Pickers
- Issue Damage Flags
- Inspection Item Photos
- Inspection Item Form
- Main Tab Navigation
- Site Racking Specs
- Scene Delegate Lifecycle
- Forgot Password Screen
- Camera Capture Session
- Site Racking Coding Keys
- App Theme Colors
- Inspection Form State
- Report Share Activities
- Catalog Seeding
- Site Racking Form Cards
- Core Data Manager
- Customer Directory Screen
- Performance Optimizer
- Customer Directory Cells
- Issue Tree Model
- Site Racking Model
- Mail Compose Errors
- Inspection Form ViewModel
- Crypto And Foundation Imports
- Framework Import Cluster
- Customer Directory ViewModel
- Empty State View
- Issue Selection Screen
- CloudKit Error Types
- Site Racking Recorded Flags
- Inspection Form Layout
- App Delegate Lifecycle
- App Theme Font Styles
- Inspection Form Interactions
- App Icon Racking Scene
- Company UserDefaults Keys
- Inspection Item Issues
- Launch Icon Rack Scene
- Toast Notifications
- Site Document Files
- UIScene Session Config
- Core Data Notifications
- CloudKit Status Handling
- Customer Search Filtering
- Inspection Camera Picker
- Inspection Form Mode
- CloudKit Sync Status
- Generic Core Data Fetch
- Memory Usage Metrics
- Photo Strip Callbacks
- Issue Table Data Source
- App Theme Fonts
- Company Logo Branding
- Firebase Analytics Imports

## God Nodes (most connected - your core abstractions)
1. `InspectionItemFormViewController` - 76 edges
2. `SiteRackingViewController` - 62 edges
3. `ReportViewController` - 55 edges
4. `CustomerFormViewController` - 44 edges
5. `SiteRacking` - 43 edges
6. `Flag` - 42 edges
7. `SettingsViewController` - 39 edges
8. `UserManager` - 39 edges
9. `CoreDataManager` - 35 edges
10. `Customer` - 34 edges

## Surprising Connections (you probably didn't know these)
- `CustomerDirectoryViewController` --calls--> `CustomerDirectoryViewModel`  [INFERRED]
  CustomerDirectoryViewController.swift → CustomerDirectoryViewModel.swift
- `InspectionItemFormViewController` --calls--> `InspectionPhotoStripView`  [INFERRED]
  InspectionItemFormViewController.swift → InspectionPhotoStripView.swift
- `ReportViewController` --calls--> `ReportGenerator`  [INFERRED]
  ReportViewController.swift → ReportGenerator.swift
- `AccountCreationViewController` --references--> `String`  [EXTRACTED]
  AccountCreationViewController.swift → ImageCacheManager.swift
- `EventCategory` --implements--> `String`  [EXTRACTED]
  AnalyticsManager.swift → ImageCacheManager.swift

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Pallet Storage System** — systems_inspector_assets_xcassets_appicon_appiconset_rackicon_upright_frames, systems_inspector_assets_xcassets_appicon_appiconset_rackicon_load_beams, systems_inspector_assets_xcassets_appicon_appiconset_rackicon_wooden_pallets, systems_inspector_assets_xcassets_appicon_appiconset_rackicon_cardboard_cartons [EXTRACTED 1.00]
- **Pallet Rack Storage Assembly** — systems_inspector_assets_xcassets_launchicon_imageset_rackicon_upright_frames, systems_inspector_assets_xcassets_launchicon_imageset_rackicon_load_beams, systems_inspector_assets_xcassets_launchicon_imageset_rackicon_beam_decking, systems_inspector_assets_xcassets_launchicon_imageset_rackicon_wooden_pallets, systems_inspector_assets_xcassets_launchicon_imageset_rackicon_palletized_cartons [EXTRACTED 1.00]
- **Working Warehouse Occupancy Scene** — systems_inspector_assets_xcassets_launchicon_imageset_rackicon_selective_pallet_racking, systems_inspector_assets_xcassets_launchicon_imageset_rackicon_mixed_bay_occupancy, systems_inspector_assets_xcassets_launchicon_imageset_rackicon_floor_pallet_storage [INFERRED 0.85]
- **Eastern Lift Truck Co. Brand Lockup** — systems_inspector_assets_xcassets_company_logo_imageset_thumbnail_outlook_b1qxddk4_company_logo, systems_inspector_assets_xcassets_company_logo_imageset_thumbnail_outlook_b1qxddk4_eastern_lift_truck_co, systems_inspector_assets_xcassets_company_logo_imageset_thumbnail_outlook_b1qxddk4_warehouse_products_group, systems_inspector_assets_xcassets_company_logo_imageset_thumbnail_outlook_b1qxddk4_forklift_emblem [EXTRACTED 1.00]

## Communities (66 total, 9 thin omitted)

### Community 0 - "Report Dates And PDF"
Cohesion: 0.05
Nodes (54): DateFormatter, DateFormatters, Date, String, NSAttributedString, PDFKit, PDFItemLayoutInput, .trimmedComments (+46 more)

### Community 1 - "Filter Preset Storage"
Cohesion: 0.05
Nodes (30): FilterPreset, FilterPresetStorage, Int, QLPreviewControllerDataSource, Filter, ReportFromInspections, Selection, Bool (+22 more)

### Community 2 - "Image Cache Manager"
Cohesion: 0.05
Nodes (21): AnyObject, HelpAndSupportTableViewController, SettingsActionsDelegate, ImageCacheManager, CGFloat, Int, UIImage, URL (+13 more)

### Community 3 - "Account Creation Screen"
Cohesion: 0.06
Nodes (19): AccountCreationViewController, Bool, NSNotification, UIActivityIndicatorView, UIButton, UILabel, UITextField, UIView (+11 more)

### Community 4 - "Customer Form State"
Cohesion: 0.06
Nodes (20): UUID, CustomerFormState, .isValid, .siteRackingSubtitle, Bool, CustomerFormDelegate, CustomerFormViewController, Bool (+12 more)

### Community 5 - "Account Lockout Manager"
Cohesion: 0.06
Nodes (15): AccountLockoutManager, Keys, Notification.Name, Bool, Int, TimeInterval, HapticManager, LocalAuthentication (+7 more)

### Community 6 - "Customer Details Screen"
Cohesion: 0.07
Nodes (18): CustomerDetailsViewController, InspectionDetailsViewController, InspectionItemDetailViewController, Bool, CGPoint, IndexPath, Inspection, InspectionItem (+10 more)

### Community 7 - "Analytics Event Logging"
Cohesion: 0.06
Nodes (23): AnalyticsManager, EventCategory, authentication, customers, errors, inspections, performance, security (+15 more)

### Community 8 - "PDF Table Layout"
Cohesion: 0.08
Nodes (30): CaseIterable, ClosedRange, Column, ColumnBuilder, PDFResolvedTableLayout, .bodyFont, .smallFont, .totalWidth (+22 more)

### Community 9 - "Filter Chips Photo Strip"
Cohesion: 0.07
Nodes (22): CAGradientLayer, FilterChipView, NSCoder, Void, InspectionPhotoStripView, InspectionPhotoStripViewDelegate, PhotoPreviewViewController, CGRect (+14 more)

### Community 10 - "Site Racking Pickers"
Cohesion: 0.09
Nodes (13): PHPickerResult, PHPickerViewController, PHPickerViewControllerDelegate, SiteRackingViewController, Any, Bool, UIButton, UIDocumentPickerViewController (+5 more)

### Community 11 - "Issue Damage Flags"
Cohesion: 0.06
Nodes (36): Flag, aisleGuarding, aisleGuardingDamaged, aisleGuardingMissing, aisleGuardingRepairRequired, anchors, anchorsDamaged, anchorsMissing (+28 more)

### Community 12 - "Inspection Item Photos"
Cohesion: 0.13
Nodes (15): InspectionItem, .hasPhoto, .localPhotoFilePredicate, .photoCount, Bool, CGFloat, Int, NSManagedObjectContext (+7 more)

### Community 13 - "Inspection Item Form"
Cohesion: 0.10
Nodes (10): InspectionItemFormDelegate, InspectionItemFormViewController, .hasContent, Bool, UIScrollView, UIStackView, UITextField, UIImagePickerControllerDelegate (+2 more)

### Community 14 - "Main Tab Navigation"
Cohesion: 0.12
Nodes (12): MainTabBarController, Bool, Int, Notification, UIImage, UIImageView, UIViewController, UINavigationBar (+4 more)

### Community 15 - "Site Racking Specs"
Cohesion: 0.18
Nodes (17): Codable, Decoder, Equatable, AnchorSpec, BeamSpec, CrossBarSpec, DeckSpec, LoadInformation (+9 more)

### Community 16 - "Scene Delegate Lifecycle"
Cohesion: 0.10
Nodes (13): SceneDelegate, Set, UIScene, UISceneSession, UIWindow, URL, SplashViewController, Bool (+5 more)

### Community 17 - "Forgot Password Screen"
Cohesion: 0.12
Nodes (7): ForgotPasswordViewController, UIActivityIndicatorView, UIButton, UILabel, UITextField, PasswordRecoveryManager, Bool

### Community 18 - "Camera Capture Session"
Cohesion: 0.12
Nodes (10): AVCaptureDevice, AVCapturePhoto, AVCapturePhotoCaptureDelegate, AVCapturePhotoOutput, AVCaptureSession, AVCaptureVideoPreviewLayer, CameraViewController, CameraViewControllerDelegate (+2 more)

### Community 19 - "Site Racking Coding Keys"
Cohesion: 0.09
Nodes (22): CodingKey, CodingKeys, anchors, beams, capacity, construction, crossBars, decks (+14 more)

### Community 20 - "App Theme Colors"
Cohesion: 0.10
Nodes (18): AppTheme, .background, .destructive, .overlay, .placeholder, .primary, .primaryContrast, .primaryGradientEnd (+10 more)

### Community 21 - "Inspection Form State"
Cohesion: 0.18
Nodes (12): InspectionItemFormState, .atPhotoCap, .hasContent, .issueDisplayLabels, .isValid, Bool, Set, UIImage (+4 more)

### Community 22 - "Report Share Activities"
Cohesion: 0.12
Nodes (14): CopySummaryActivity, .activityImage, .activityTitle, .activityType, EmailReportActivity, .activityImage, .activityTitle, .activityType (+6 more)

### Community 23 - "Catalog Seeding"
Cohesion: 0.25
Nodes (12): Catalog, CatalogAddResult, added, blank, duplicate, CatalogKind, deckType, manufacturer (+4 more)

### Community 24 - "Site Racking Form Cards"
Cohesion: 0.23
Nodes (5): Int, QLPreviewController, QLPreviewItem, UITextField, UIView

### Community 25 - "Core Data Manager"
Cohesion: 0.14
Nodes (11): CoreDataManager, .context, .currentCloudKitSyncStatus, .isStoreLoaded, Bool, NSManagedObjectContext, NSPredicate, URL (+3 more)

### Community 26 - "Customer Directory Screen"
Cohesion: 0.16
Nodes (8): CustomerDirectoryViewController, Bool, CGFloat, IndexPath, Int, UITableView, Timer, UISwipeActionsConfiguration

### Community 27 - "Performance Optimizer"
Cohesion: 0.18
Nodes (8): PerformanceMetrics, PerformanceOptimizer, CGFloat, Date, Int, NSFetchRequest, TimeInterval, UUID

### Community 28 - "Customer Directory Cells"
Cohesion: 0.19
Nodes (7): Combine, CustomerCell, LoadingCell, NSCoder, UIActivityIndicatorView, UILabel, UITableViewCell

### Community 29 - "Issue Tree Model"
Cohesion: 0.37
Nodes (7): Hashable, Issue, Node, Path, .name, Bool, Set

### Community 30 - "Site Racking Model"
Cohesion: 0.20
Nodes (14): Row, SiteRacking, .anchorsRecorded, .beamsRecorded, .crossBarsRecorded, .decksRecorded, .empty, .isEmpty (+6 more)

### Community 31 - "Mail Compose Errors"
Cohesion: 0.13
Nodes (11): MFMailComposeResult, MFMailComposeViewController, MFMailComposeResult, MFMailComposeViewController, MFMailComposeResult, MFMailComposeViewController, Error, derivationFailed (+3 more)

### Community 32 - "Inspection Form ViewModel"
Cohesion: 0.21
Nodes (7): InspectionFormViewModel, .inspection, Bool, Date, Inspection, Inspection, NSObject

### Community 33 - "Crypto And Foundation Imports"
Cohesion: 0.20
Nodes (4): CommonCrypto, CoreData, CryptoKit, Foundation

### Community 34 - "Framework Import Cluster"
Cohesion: 0.20
Nodes (7): AVFoundation, Firebase, MessageUI, PhotosUI, QuickLook, UIKit, UniformTypeIdentifiers

### Community 35 - "Customer Directory ViewModel"
Cohesion: 0.22
Nodes (6): Customer, Set, CustomerDirectoryViewModel, Bool, Int, Void

### Community 36 - "Empty State View"
Cohesion: 0.16
Nodes (9): EmptyStateView, CGFloat, CGRect, NSCoder, UIButton, UIColor, UILabel, UIStackView (+1 more)

### Community 37 - "Issue Selection Screen"
Cohesion: 0.19
Nodes (6): IssueSelectionDelegate, IssueSelectionViewController, Set, UISearchController, UISearchResultsUpdating, UITableViewDataSource

### Community 38 - "CloudKit Error Types"
Cohesion: 0.15
Nodes (12): CloudKit, CloudKitError, accountRestricted, couldNotDetermine, .errorDescription, noAccount, temporarilyUnavailable, unknown (+4 more)

### Community 39 - "Site Racking Recorded Flags"
Cohesion: 0.22
Nodes (3): .isRecorded, .isRecorded, Bool

### Community 40 - "Inspection Form Layout"
Cohesion: 0.21
Nodes (4): NSNotification, UIButton, UILabel, UIView

### Community 41 - "App Delegate Lifecycle"
Cohesion: 0.25
Nodes (6): AppDelegate, UITabBarController, UIWindow, UIApplication, UIApplicationDelegate, UIResponder

### Community 42 - "App Theme Font Styles"
Cohesion: 0.18
Nodes (11): FontStyle, body, callout, caption, footnote, headline, largeTitle, subheadline (+3 more)

### Community 44 - "App Icon Racking Scene"
Cohesion: 0.29
Nodes (10): Systems Inspector App Icon, Cardboard Cartons, Empty Beam Levels, Floor Pallet Storage, Load Beams, Pallet Racking, Selective Pallet Rack, Upright Frames (+2 more)

### Community 45 - "Company UserDefaults Keys"
Cohesion: 0.28
Nodes (6): UserDefaults, UserDefaultsKeys, companyAddress, companyName, companyPhone, inspectorName

### Community 46 - "Inspection Item Issues"
Cohesion: 0.36
Nodes (3): InspectionItem, Bool, Set

### Community 47 - "Launch Icon Rack Scene"
Cohesion: 0.33
Nodes (9): Beam-Level Decking, Floor-Level Pallet Storage, Launch Icon Rack Scene, Horizontal Load Beams, Mixed Bay Occupancy, Palletized Cardboard Cartons, Selective Pallet Racking, Steel Upright Frames (+1 more)

### Community 48 - "Toast Notifications"
Cohesion: 0.29
Nodes (4): TimeInterval, UIViewController, Void, ToastView

### Community 49 - "Site Document Files"
Cohesion: 0.32
Nodes (4): SiteDocumentFile, UUID, NSCoder, NSManagedObjectContext

### Community 50 - "UIScene Session Config"
Cohesion: 0.29
Nodes (6): Any, Bool, Set, UIScene, UISceneSession, UISceneConfiguration

### Community 51 - "Core Data Notifications"
Cohesion: 0.33
Nodes (3): Notification, Set, NSManagedObject

### Community 55 - "Inspection Form Mode"
Cohesion: 0.33
Nodes (5): Mode, create, edit, InspectionItem, NSCoder

### Community 56 - "CloudKit Sync Status"
Cohesion: 0.40
Nodes (5): CloudKitSyncStatus, failed, inProgress, notStarted, succeeded

### Community 57 - "Generic Core Data Fetch"
Cohesion: 0.50
Nodes (3): Int, NSFetchRequest, T

### Community 58 - "Memory Usage Metrics"
Cohesion: 0.40
Nodes (4): Double, MemoryUsage, .formattedString, .percentage

### Community 61 - "Issue Table Data Source"
Cohesion: 0.40
Nodes (4): IndexPath, Int, UITableView, UITableViewCell

### Community 63 - "Company Logo Branding"
Cohesion: 0.83
Nodes (4): Eastern Lift Truck Co. Company Logo, Eastern Lift Truck Co., Forklift Circular Emblem, Warehouse Products Group

## Knowledge Gaps
- **184 isolated node(s):** `Notification.Name`, `FirebaseAnalytics`, `FirebaseCrashlytics`, `authentication`, `customers` (+179 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 407 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **9 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `String` connect `Report Dates And PDF` to `Filter Preset Storage`, `Image Cache Manager`, `Account Creation Screen`, `Customer Form State`, `Account Lockout Manager`, `Customer Details Screen`, `Analytics Event Logging`, `PDF Table Layout`, `Filter Chips Photo Strip`, `Site Racking Pickers`, `Issue Damage Flags`, `Inspection Item Photos`, `Inspection Item Form`, `Main Tab Navigation`, `Site Racking Specs`, `Scene Delegate Lifecycle`, `Forgot Password Screen`, `Camera Capture Session`, `Site Racking Coding Keys`, `Inspection Form State`, `Report Share Activities`, `Catalog Seeding`, `Site Racking Form Cards`, `Performance Optimizer`, `Customer Directory Cells`, `Issue Tree Model`, `Site Racking Model`, `Framework Import Cluster`, `Customer Directory ViewModel`, `Empty State View`, `Issue Selection Screen`, `CloudKit Error Types`, `Site Racking Recorded Flags`, `Inspection Form Layout`, `Company UserDefaults Keys`, `Toast Notifications`, `Site Document Files`, `Customer Search Filtering`, `Inspection Camera Picker`, `Memory Usage Metrics`?**
  _High betweenness centrality (0.627) - this node is a cross-community bridge._
- **Why does `InspectionItemFormViewController` connect `Inspection Item Form` to `Inspection Form ViewModel`, `Account Creation Screen`, `Issue Selection Screen`, `Customer Details Screen`, `Inspection Form Layout`, `Filter Chips Photo Strip`, `Inspection Form Interactions`, `Main Tab Navigation`, `Inspection Form State`, `Inspection Camera Picker`, `Inspection Form Mode`, `Photo Strip Callbacks`, `Inspection Form Chrome`, `App Theme Fonts`?**
  _High betweenness centrality (0.081) - this node is a cross-community bridge._
- **Why does `Flag` connect `Issue Damage Flags` to `PDF Table Layout`, `Report Dates And PDF`, `Issue Tree Model`?**
  _High betweenness centrality (0.063) - this node is a cross-community bridge._
- **Are the 6 inferred relationships involving `InspectionItemFormViewController` (e.g. with `.addInspectionTapped()` and `.editInspectionItem()`) actually correct?**
  _`InspectionItemFormViewController` has 6 INFERRED edges - model-reasoned connections that need verification._
- **Are the 2 inferred relationships involving `SiteRackingViewController` (e.g. with `.siteRackingTapped()` and `.siteRackingTapped()`) actually correct?**
  _`SiteRackingViewController` has 2 INFERRED edges - model-reasoned connections that need verification._
- **Are the 4 inferred relationships involving `ReportViewController` (e.g. with `.createMainTabBarController()` and `.setupViewControllers()`) actually correct?**
  _`ReportViewController` has 4 INFERRED edges - model-reasoned connections that need verification._
- **Are the 3 inferred relationships involving `CustomerFormViewController` (e.g. with `.editCustomerTapped()` and `.addCustomerTapped()`) actually correct?**
  _`CustomerFormViewController` has 3 INFERRED edges - model-reasoned connections that need verification._